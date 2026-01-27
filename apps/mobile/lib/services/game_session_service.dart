import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/game_session.dart';

final supabase = Supabase.instance.client;

class GameSessionService {
  // Start a new game session
  static Future<GameSession> startGame({
    required String courtId,
    required String challengeType,
    required List<String> teamAPlayers,
    required List<String> teamBPlayers,
  }) async {
    try {
      // Create game session
      final sessionResponse = await supabase
          .from('game_sessions')
          .insert({
            'court_id': courtId,
            'challenge_type': challengeType,
            'status': 'active',
          })
          .select()
          .single();

      final session = GameSession.fromJson(sessionResponse);

      // Add team A players
      for (int i = 0; i < teamAPlayers.length; i++) {
        await supabase.from('game_session_players').insert({
          'game_session_id': session.id,
          'user_id': teamAPlayers[i],
          'team': 'team_a',
          'position': i + 1,
        });
      }

      // Add team B players
      for (int i = 0; i < teamBPlayers.length; i++) {
        await supabase.from('game_session_players').insert({
          'game_session_id': session.id,
          'user_id': teamBPlayers[i],
          'team': 'team_b',
          'position': i + 1,
        });
      }

      return session;
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

  // Update game score
  static Future<GameSession> updateScore({
    required String gameId,
    required int teamAScore,
    required int teamBScore,
  }) async {
    try {
      final response = await supabase
          .from('game_sessions')
          .update({
            'team_a_score': teamAScore,
            'team_b_score': teamBScore,
          })
          .eq('id', gameId)
          .select()
          .single();

      return GameSession.fromJson(response);
    } catch (e) {
      print('Error updating score: $e');
      rethrow;
    }
  }

  // End game and record winner
  static Future<GameSession> endGame({
    required String gameId,
    required String winnerTeam,
  }) async {
    try {
      final response = await supabase
          .from('game_sessions')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toIso8601String(),
            'winner_team': winnerTeam,
          })
          .eq('id', gameId)
          .select()
          .single();

      // Update player stats
      await _updatePlayerStats(gameId, winnerTeam);
      
      // Mark associated challenge as completed
      await _completeChallenge(gameId);

      return GameSession.fromJson(response);
    } catch (e) {
      print('Error ending game: $e');
      rethrow;
    }
  }

  // Get active game at a court
  static Future<GameSession?> getActiveGame(String courtId) async {
    try {
      final response = await supabase
          .from('game_sessions')
          .select()
          .eq('court_id', courtId)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return GameSession.fromJson(response);
    } catch (e) {
      print('Error getting active game: $e');
      return null;
    }
  }

  // Get user's recent games
  static Future<List<GameSession>> getUserGames(String userId, {int limit = 10}) async {
    try {
      final response = await supabase
          .from('game_sessions')
          .select('*, game_session_players!inner(*)')
          .eq('game_session_players.user_id', userId)
          .order('started_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => GameSession.fromJson(json)).toList();
    } catch (e) {
      print('Error getting user games: $e');
      return [];
    }
  }

  // Update player stats after game ends
  static Future<void> _updatePlayerStats(String gameId, String winnerTeam) async {
    try {
      final players = await supabase
          .from('game_session_players')
          .select('user_id, team')
          .eq('game_session_id', gameId);

      final game = await supabase
          .from('game_sessions')
          .select()
          .eq('id', gameId)
          .single();

      for (final player in players) {
        final userId = player['user_id'] as String;
        final team = player['team'] as String;
        final isWinner = team == winnerTeam;

        // Get or create player stats
        final existingStats = await supabase
            .from('player_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        final teamScore = team == 'team_a' 
            ? game['team_a_score'] as int 
            : game['team_b_score'] as int;
        final opponentScore = team == 'team_a' 
            ? game['team_b_score'] as int 
            : game['team_a_score'] as int;

        if (existingStats == null) {
          // Create new stats
          await supabase.from('player_stats').insert({
            'user_id': userId,
            'total_games': 1,
            'total_wins': isWinner ? 1 : 0,
            'total_losses': isWinner ? 0 : 1,
            'total_points_scored': teamScore,
            'total_points_against': opponentScore,
          });
        } else {
          // Update existing stats
          await supabase
              .from('player_stats')
              .update({
                'total_games': (existingStats['total_games'] as int) + 1,
                'total_wins': (existingStats['total_wins'] as int) + (isWinner ? 1 : 0),
                'total_losses': (existingStats['total_losses'] as int) + (isWinner ? 0 : 1),
                'total_points_scored': (existingStats['total_points_scored'] as int) + teamScore,
                'total_points_against': (existingStats['total_points_against'] as int) + opponentScore,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        }
      }
    } catch (e) {
      print('Error updating player stats: $e');
    }
  }

  // Start a game from a challenge (new method for challenge completion flow)
  static Future<GameSession> startGameFromChallenge({
    required String challengeId,
    required String courtId,
    required String creatorId,
    required String opponentId,
    required String challengeType,
  }) async {
    try {
      // Create game session linked to challenge
      final sessionResponse = await supabase
          .from('game_sessions')
          .insert({
            'court_id': courtId,
            'challenge_type': challengeType,
            'status': 'active',
            'challenge_id': challengeId,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final session = GameSession.fromJson(sessionResponse);

      // Add creator as team A
      await supabase.from('game_session_players').insert({
        'game_session_id': session.id,
        'user_id': creatorId,
        'team': 'team_a',
        'position': 1,
      });

      // Add opponent as team B
      await supabase.from('game_session_players').insert({
        'game_session_id': session.id,
        'user_id': opponentId,
        'team': 'team_b',
        'position': 1,
      });

      // Update challenge status to in_progress
      await supabase
          .from('challenges')
          .update({'status': 'in_progress'})
          .eq('id', challengeId);

      return session;
    } catch (e) {
      print('❌ Error starting game from challenge: $e');
      rethrow;
    }
  }

  // Fetch game with all related data (players and profiles)
  static Future<GameSession?> fetchGameWithPlayers(String gameId) async {
    try {
      final response = await supabase
          .from('game_sessions')
          .select()
          .eq('id', gameId)
          .single();

      return GameSession.fromJson(response);
    } catch (e) {
      print('❌ Error fetching game: $e');
      return null;
    }
  }

  // Mark challenge as completed when game ends
  static Future<void> _completeChallenge(String gameId) async {
    try {
      // Find and update associated challenge
      final game = await supabase
          .from('game_sessions')
          .select('challenge_id')
          .eq('id', gameId)
          .maybeSingle();

      if (game != null && game['challenge_id'] != null) {
        await supabase
            .from('challenges')
            .update({'status': 'completed'})
            .eq('id', game['challenge_id']);
      }
    } catch (e) {
      print('⚠️  Error completing challenge: $e');
    }
  }
}
