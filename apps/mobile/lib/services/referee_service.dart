import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/referee_profile.dart';
import 'package:mobile/models/referee_assignment.dart';
import 'package:mobile/models/challenge.dart';

final supabase = Supabase.instance.client;

class RefereeService {
  /// Fetch referee profile by user ID
  static Future<RefereeProfile> fetchRefereeProfile(String userId) async {
    try {
      final response = await supabase
          .from('referee_profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return RefereeProfile.fromJson(response);
    } catch (e) {
      print('❌ Error fetching referee profile: $e');
      throw Exception('Failed to load referee profile: $e');
    }
  }

  /// Create or update referee profile
  static Future<RefereeProfile> upsertRefereeProfile({
    required String userId,
    required String displayName,
    String? profilePictureUrl,
    String? bio,
    int? yearsExperience,
    String? availability,
    List<String>? socialMediaLinks,
    List<String>? certificates,
  }) async {
    try {
      final response = await supabase.from('referee_profiles').upsert({
        'user_id': userId,
        'display_name': displayName,
        'profile_picture_url': profilePictureUrl,
        'bio': bio,
        'years_experience': yearsExperience,
        'availability': availability,
        'social_media_links': socialMediaLinks,
        'certificates': certificates,
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      return RefereeProfile.fromJson(response);
    } catch (e) {
      print('❌ Error upserting referee profile: $e');
      throw Exception('Failed to update referee profile: $e');
    }
  }

  /// Fetch pending referee assignments for a referee
  static Future<List<Map<String, dynamic>>> getPendingRefereeGames(
      String refereeId) async {
    try {
      final response = await supabase
          .from('referee_assignments')
          .select('''
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
              opponent_id,
              courts:court_id (id, name)
            )
          ''')
          .eq('referee_id', refereeId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('❌ Error fetching pending referee games: $e');
      return [];
    }
  }

  /// Accept referee assignment
  static Future<void> acceptRefereeAssignment(String assignmentId) async {
    try {
      await supabase
          .from('referee_assignments')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      print('✅ Referee assignment accepted: $assignmentId');
    } catch (e) {
      print('❌ Error accepting referee assignment: $e');
      throw Exception('Failed to accept assignment: $e');
    }
  }

  /// Decline referee assignment
  static Future<void> declineRefereeAssignment(String assignmentId) async {
    try {
      await supabase
          .from('referee_assignments')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      print('✅ Referee assignment declined: $assignmentId');
    } catch (e) {
      print('❌ Error declining referee assignment: $e');
      throw Exception('Failed to decline assignment: $e');
    }
  }

  /// Get accepted assignments for referee (games they're assigned to)
  static Future<List<RefereeAssignment>> getAcceptedAssignments(
      String refereeId) async {
    try {
      final response = await supabase
          .from('referee_assignments')
          .select()
          .eq('referee_id', refereeId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RefereeAssignment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching accepted assignments: $e');
      return [];
    }
  }

  /// Fetch all available referees for a game
  static Future<List<RefereeProfile>> fetchAvailableReferees() async {
    try {
      final response = await supabase
          .from('referee_profiles')
          .select()
          .eq('is_verified', true)
          .order('average_rating', ascending: false);

      return (response as List)
          .map((json) => RefereeProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching available referees: $e');
      return [];
    }
  }

  /// Update games refereed count
  static Future<void> incrementGamesRefereed(String refereeId) async {
    try {
      final profile = await fetchRefereeProfile(refereeId);
      
      await supabase
          .from('referee_profiles')
          .update({
            'games_refereed_total': profile.gamesRefereedTotal + 1,
          })
          .eq('user_id', refereeId);

      print('✅ Games refereed count updated for: $refereeId');
    } catch (e) {
      print('❌ Error updating games refereed: $e');
    }
  }

  /// Get referee stats
  static Future<Map<String, dynamic>> getRefereeStats(String refereeId) async {
    try {
      final profile = await fetchRefereeProfile(refereeId);
      final acceptedAssignments = await getAcceptedAssignments(refereeId);

      return {
        'games_refereed': profile.gamesRefereedTotal,
        'average_rating': profile.averageRating ?? 0.0,
        'is_verified': profile.isVerified,
        'years_experience': profile.yearsExperience ?? 0,
        'upcoming_games': acceptedAssignments.length,
      };
    } catch (e) {
      print('❌ Error fetching referee stats: $e');
      return {
        'games_refereed': 0,
        'average_rating': 0.0,
        'is_verified': false,
        'years_experience': 0,
        'upcoming_games': 0,
      };
    }
  }

  /// Check if user is a referee
  static Future<bool> isUserReferee(String userId) async {
    try {
      final response = await supabase
          .from('referee_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Stream pending referee notifications
  static Stream<List<Map<String, dynamic>>> streamPendingRefereeNotifications(
      String refereeId) {
    return supabase
        .from('referee_assignments')
        .stream(primaryKey: ['id'])
        .map((data) => (data as List).cast<Map<String, dynamic>>())
        .where((assignments) => assignments.every((a) =>
            a['referee_id'] == refereeId && a['status'] == 'pending'))
        .map((assignments) => assignments
            .where((a) => a['referee_id'] == refereeId && a['status'] == 'pending')
            .toList());
  }

  /// Get game details for referee assignment
  static Future<Challenge> getChallengeForAssignment(String challengeId) async {
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

  /// Rate referee performance
  static Future<void> rateReferee(
    String refereeId,
    double rating,
    String comment,
  ) async {
    try {
      await supabase.from('referee_ratings').insert({
        'referee_id': refereeId,
        'rating': rating,
        'comment': comment,
        'rated_by': Supabase.instance.client.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update average rating
      final response = await supabase
          .from('referee_ratings')
          .select('rating')
          .eq('referee_id', refereeId);

      if (response.isNotEmpty) {
        final ratings = (response as List)
            .map((r) => (r['rating'] as num).toDouble())
            .toList();
        final average = ratings.reduce((a, b) => a + b) / ratings.length;

        await supabase
            .from('referee_profiles')
            .update({'average_rating': average})
            .eq('user_id', refereeId);
      }

      print('✅ Referee rated successfully');
    } catch (e) {
      print('❌ Error rating referee: $e');
      throw Exception('Failed to rate referee: $e');
    }
  }
}
