import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/models/user_level.dart';

final supabase = Supabase.instance.client;

class ChallengeService {
  /// Fetch all open challenges (available to join)
  static Future<List<Challenge>> fetchOpenChallenges() async {
    try {
      final response = await supabase
          .from('challenges')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Challenge.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching open challenges: $e');
      throw Exception('Failed to load challenges: $e');
    }
  }

  /// Fetch challenges for current user (created or joined)
  static Future<List<Challenge>> fetchMyChallenges(String userId, {String? status}) async {
    try {
      var query = supabase
          .from('challenges')
          .select()
          .or('creator_id.eq.$userId,opponent_id.eq.$userId');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => Challenge.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching user challenges: $e');
      throw Exception('Failed to load your challenges: $e');
    }
  }

  /// Fetch user level (for validation)
  static Future<UserLevel> fetchUserLevel(String userId) async {
    try {
      final response = await supabase
          .from('user_levels')
          .select()
          .eq('user_id', userId)
          .single();

      return UserLevel.fromJson(response);
    } catch (e) {
      print('⚠️  User level not found, creating rookie: $e');
      // Create default rookie level
      await supabase.from('user_levels').insert({
        'user_id': userId,
        'level': 'rookie',
        'xp': 0,
        'wins': 0,
        'losses': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return UserLevel(
        userId: userId,
        level: 'rookie',
        xp: 0,
        wins: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Fetch a single challenge by ID
  static Future<Challenge> fetchChallenge(String challengeId) async {
    try {
      final response = await supabase
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();

      return Challenge.fromJson(response);
    } catch (e) {
      print('❌ Error fetching challenge: $e');
      throw Exception('Failed to load challenge: $e');
    }
  }

  /// Create a new challenge
  static Future<Challenge> createChallenge({
    required String creatorId,
    required String opponentId,
    required String challengeType,
    required String courtId,
    required bool hasWager,
    double? wagerAmount,
  }) async {
    try {
      // Validate opponent exists
      if (opponentId.isEmpty) {
        throw Exception('Opponent ID cannot be empty');
      }

      // Check if creator is rookie
      final userLevel = await fetchUserLevel(creatorId);
      final isPending = userLevel.isRookie;

      // Verify opponent exists in profiles
      final opponentCheck = await supabase
          .from('profiles')
          .select('id')
          .eq('user_id', opponentId)
          .maybeSingle();

      if (opponentCheck == null) {
        throw Exception('Selected opponent not found. They may have deleted their account.');
      }

      final challenge = {
        'creator_id': creatorId,
        'opponent_id': opponentId,
        'challenge_type': challengeType,
        'court_id': courtId,
        'status': isPending ? 'pending_approval' : 'open',
        'has_wager': hasWager,
        'wager_amount': wagerAmount ?? 0,
        'creator_agreed_to_scoring': false,
        'opponent_agreed_to_scoring': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('challenges')
          .insert(challenge)
          .select()
          .single();

      return Challenge.fromJson(response);
    } catch (e) {
      print('❌ Error creating challenge: $e');
      throw Exception('Failed to create challenge: $e');
    }
  }

  /// Accept a challenge (opponent accepts)
  static Future<void> acceptChallenge(String challengeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'status': 'accepted'})
          .eq('id', challengeId);
    } catch (e) {
      print('❌ Error accepting challenge: $e');
      throw Exception('Failed to accept challenge: $e');
    }
  }

  /// Decline a challenge (opponent declines)
  static Future<void> declineChallenge(String challengeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'status': 'declined'})
          .eq('id', challengeId);
    } catch (e) {
      print('❌ Error declining challenge: $e');
      throw Exception('Failed to decline challenge: $e');
    }
  }

  /// Agree to scoring method
  static Future<void> agreeToScoringMethod(
    String challengeId,
    String scoringMethod,
    bool isCreator,
  ) async {
    try {
      final updateData = isCreator
          ? {
              'scoring_method': scoringMethod,
              'creator_agreed_to_scoring': true,
            }
          : {
              'scoring_method': scoringMethod,
              'opponent_agreed_to_scoring': true,
            };

      await supabase
          .from('challenges')
          .update(updateData)
          .eq('id', challengeId);
    } catch (e) {
      print('❌ Error updating scoring agreement: $e');
      throw Exception('Failed to update scoring agreement: $e');
    }
  }

  /// Approve a pending challenge (admin/dev only)
  static Future<void> approveChallenge(String challengeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'status': 'open'})
          .eq('id', challengeId);
      
      print('✅ Challenge approved: $challengeId');
    } catch (e) {
      print('❌ Error approving challenge: $e');
      throw Exception('Failed to approve challenge: $e');
    }
  }

  /// Fetch opponent name by user ID
  static Future<String> fetchOpponentName(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('username, display_name')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return 'Unknown Player';
      }

      return (response['display_name'] as String?) ?? 
             (response['username'] as String?) ?? 
             'Unknown Player';
    } catch (e) {
      print('❌ Error fetching opponent name: $e');
      return 'Unknown Player';
    }
  }

  /// Join a challenge as the opponent
  static Future<Challenge> joinChallenge(String challengeId, String userId) async {
    try {
      // Update challenge with opponent_id and status to accepted
      final response = await supabase
          .from('challenges')
          .update({
            'opponent_id': userId,
            'status': 'accepted',
          })
          .eq('id', challengeId)
          .select()
          .single();

      print('✅ Joined challenge: $challengeId');
      return Challenge.fromJson(response);
    } catch (e) {
      print('❌ Error joining challenge: $e');
      throw Exception('Failed to join challenge: $e');
    }
  }

  /// Mark challenge as completed
  static Future<void> completeChallenge(String challengeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'status': 'completed'})
          .eq('id', challengeId);

      print('✅ Challenge completed: $challengeId');
    } catch (e) {
      print('⚠️  Error completing challenge: $e');
    }
  }

  /// Set creator or opponent ready status
  static Future<void> setPlayerReady(String challengeId, String userId, bool ready) async {
    try {
      final challenge = await fetchChallenge(challengeId);
      final isCreator = challenge.creatorId == userId;
      
      final updateField = isCreator ? 'creator_ready' : 'opponent_ready';
      
      await supabase
          .from('challenges')
          .update({updateField: ready})
          .eq('id', challengeId);

      print('✅ Player ready status updated: $updateField = $ready');
    } catch (e) {
      print('❌ Error updating ready status: $e');
      throw Exception('Failed to update ready status: $e');
    }
  }

  /// Set scheduled start time for challenge
  static Future<void> setScheduledStartTime(
      String challengeId, DateTime scheduledTime) async {
    try {
      await supabase
          .from('challenges')
          .update({'scheduled_start_time': scheduledTime.toIso8601String()})
          .eq('id', challengeId);

      print('✅ Scheduled start time set: $scheduledTime');
    } catch (e) {
      print('❌ Error setting scheduled start time: $e');
      throw Exception('Failed to set scheduled start time: $e');
    }
  }

  /// Request referee for challenge
  static Future<void> requestReferee(String challengeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'referee_requested': true})
          .eq('id', challengeId);

      // Get the challenge details to fetch court and player info
      final challenge = await supabase
          .from('challenges')
          .select('court_id, creator_id')
          .eq('id', challengeId)
          .single();

      final courtId = challenge['court_id'] as String?;
      final creatorId = challenge['creator_id'] as String?;

      // Get court name
      String courtName = 'Unknown Court';
      if (courtId != null) {
        final court = await supabase
            .from('courts')
            .select('name')
            .eq('id', courtId)
            .single();
        courtName = court['name'] as String? ?? 'Unknown Court';
      }

      // For now, send notification to test referee (hardcoded for demo)
      // In production, this would send to all available referees
      const testRefereeId = 'test-referee-id'; // This is a placeholder
      
      // Try to find a test referee account from the database
      try {
        final referees = await supabase
            .from('profiles')
            .select('user_id')
            .eq('user_role', 'referee')
            .limit(1);
        
        if (referees.isNotEmpty) {
          final refereeUserId = referees[0]['user_id'] as String;
          
          // Send notification
          await supabase.from('notifications').insert({
            'user_id': refereeUserId,
            'type': 'referee_request',
            'title': '🏀 Referee Needed at $courtName',
            'message': 'A game is ready and needs a referee. Accept to ref the game!',
            'data': {
              'challenge_id': challengeId,
              'court_id': courtId,
              'court_name': courtName,
            },
          });
        }
      } catch (e) {
        print('Note: Could not send referee notification - $e');
        // Don't fail the request if notification fails
      }

      print('✅ Referee requested for challenge: $challengeId');
    } catch (e) {
      print('❌ Error requesting referee: $e');
      throw Exception('Failed to request referee: $e');
    }
  }

  /// Get available referees (users with referee role/badge)
  static Future<List<Map<String, dynamic>>> getAvailableReferees() async {
    try {
      // Query for referees - this would be users marked as referees in their profile
      final response = await supabase
          .from('profiles')
          .select('id, display_name, profile_picture_url')
          .eq('is_referee', true)
          .order('display_name');

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('❌ Error fetching available referees: $e');
      return [];
    }
  }

  /// Create referee assignment notification
  static Future<void> requestRefereeAssignment(
      String challengeId, String refereeId) async {
    try {
      await supabase.from('referee_assignments').insert({
        'challenge_id': challengeId,
        'referee_id': refereeId,
        'status': 'pending',
      });

      print('✅ Referee assignment created for $refereeId');
    } catch (e) {
      print('❌ Error creating referee assignment: $e');
      throw Exception('Failed to assign referee: $e');
    }
  }

  /// Get pending referee assignments for a user
  static Future<List<Map<String, dynamic>>> getPendingRefereeAssignments(
      String refereeId) async {
    try {
      final response = await supabase
          .from('referee_assignments')
          .select(
              '''
            id,
            challenge_id,
            status,
            created_at,
            challenges:challenge_id (
              id,
              challenge_type,
              court_id,
              scheduled_start_time,
              creator_id,
              opponent_id
            )
          ''')
          .eq('referee_id', refereeId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('❌ Error fetching referee assignments: $e');
      return [];
    }
  }

  /// Update referee assignment status
  static Future<void> updateRefereeAssignmentStatus(
      String assignmentId, String status) async {
    try {
      await supabase
          .from('referee_assignments')
          .update({'status': status, 'responded_at': DateTime.now().toIso8601String()})
          .eq('id', assignmentId);

      print('✅ Referee assignment updated: $status');
    } catch (e) {
      print('❌ Error updating referee assignment: $e');
      throw Exception('Failed to update assignment: $e');
    }
  }

  /// Assign referee to challenge
  static Future<void> assignRefereeToChallenge(
      String challengeId, String refereeId) async {
    try {
      await supabase
          .from('challenges')
          .update({'assigned_referee_id': refereeId})
          .eq('id', challengeId);

      print('✅ Referee assigned to challenge: $refereeId');
    } catch (e) {
      print('❌ Error assigning referee: $e');
      throw Exception('Failed to assign referee: $e');
    }
  }

  /// Check if player should be marked as no-show (forfeit)
  static Future<bool> checkNoShow(String challengeId, String userId) async {
    try {
      final challenge = await fetchChallenge(challengeId);
      
      if (challenge.scheduledStartTime == null) return false;
      
      final now = DateTime.now();
      final fiveMinutesAfterStart = challenge.scheduledStartTime!.add(Duration(minutes: 5));
      
      // If it's past the 5-minute grace period and player hasn't marked as ready
      if (now.isAfter(fiveMinutesAfterStart)) {
        final isCreator = challenge.creatorId == userId;
        final isReady = isCreator ? challenge.creatorReady : challenge.opponentReady;
        
        if (!isReady) {
          return true; // Player is a no-show
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking no-show: $e');
      return false;
    }
  }

  /// Record forfeit (no-show)
  static Future<void> recordForfeit(String challengeId, String userIdWhoForfeited) async {
    try {
      final challenge = await fetchChallenge(challengeId);
      
      // Determine the winner (the player who didn't forfeit)
      final winnerId = challenge.creatorId == userIdWhoForfeited 
          ? challenge.opponentId 
          : challenge.creatorId;

      await supabase
          .from('challenges')
          .update({
            'status': 'completed',
            'winner_id': winnerId,
          })
          .eq('id', challengeId);

      // Update the forfeiter's stats (add a loss)
      final stats = await supabase
          .from('player_stats')
          .select()
          .eq('user_id', userIdWhoForfeited)
          .single();

      await supabase
          .from('player_stats')
          .update({
            'total_games': (stats['total_games'] as int) + 1,
            'total_losses': (stats['total_losses'] as int) + 1,
          })
          .eq('user_id', userIdWhoForfeited);

      print('✅ Forfeit recorded for user: $userIdWhoForfeited');
    } catch (e) {
      print('❌ Error recording forfeit: $e');
      throw Exception('Failed to record forfeit: $e');
    }
  }

  /// Accept referee request for a challenge
  static Future<void> acceptRefereRequest(String challengeId) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update challenge to mark referee as accepted
      await supabase
          .from('challenges')
          .update({
            'referee_id': currentUser.id,
            'referee_accepted': true,
          })
          .eq('id', challengeId);

      // Fetch challenge to get creator and opponent IDs
      final challenge = await fetchChallenge(challengeId);

      // Send notifications to both players that referee accepted
      final notificationService = supabase;
      
      // Notification to creator
      await notificationService
          .from('notifications')
          .insert({
            'user_id': challenge.creatorId,
            'type': 'referee_accepted',
            'title': '✓ Referee Ready',
            'message': 'Referee has been assigned to your game',
            'data': {
              'challenge_id': challengeId,
              'referee_id': currentUser.id,
            },
          });

      // Notification to opponent
      await notificationService
          .from('notifications')
          .insert({
            'user_id': challenge.opponentId,
            'type': 'referee_accepted',
            'title': '✓ Referee Ready',
            'message': 'Referee has been assigned to your game',
            'data': {
              'challenge_id': challengeId,
              'referee_id': currentUser.id,
            },
          });

      print('✅ Referee accepted challenge: $challengeId');
    } catch (e) {
      print('❌ Error accepting referee request: $e');
      rethrow;
    }
  }

  /// Decline referee request for a challenge
  static Future<void> declineRefereRequest(String challengeId) async {
    try {
      // Fetch challenge to get creator and opponent IDs
      final challenge = await fetchChallenge(challengeId);

      // Clear referee request
      await supabase
          .from('challenges')
          .update({
            'referee_requested': false,
          })
          .eq('id', challengeId);

      // Send notifications to both players that referee declined
      final notificationService = supabase;
      
      // Notification to creator
      await notificationService
          .from('notifications')
          .insert({
            'user_id': challenge.creatorId,
            'type': 'referee_declined',
            'title': '✗ Referee Unavailable',
            'message': 'Referee declined. Please request another referee.',
            'data': {
              'challenge_id': challengeId,
            },
          });

      // Notification to opponent
      await notificationService
          .from('notifications')
          .insert({
            'user_id': challenge.opponentId,
            'type': 'referee_declined',
            'title': '✗ Referee Unavailable',
            'message': 'Referee declined. Please request another referee.',
            'data': {
              'challenge_id': challengeId,
            },
          });

      print('✅ Referee declined challenge: $challengeId');
    } catch (e) {
      print('❌ Error declining referee request: $e');
      rethrow;
    }
  }
}
