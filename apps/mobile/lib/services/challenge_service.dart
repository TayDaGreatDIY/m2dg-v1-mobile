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
}
