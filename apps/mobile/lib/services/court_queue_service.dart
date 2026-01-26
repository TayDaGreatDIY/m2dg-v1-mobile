import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/court_queue.dart';

final supabase = Supabase.instance.client;

class CourtQueueService {
  // Add player to waiting queue
  static Future<CourtQueue> joinQueue(
    String courtId, {
    int teamSize = 1,
    List<String>? additionalPlayers,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get current queue count for position
      final queueResponse = await supabase
          .from('court_queues')
          .select('position_in_queue')
          .eq('court_id', courtId)
          .eq('status', 'waiting')
          .order('position_in_queue', ascending: false)
          .limit(1);

      final nextPosition = queueResponse.isEmpty
          ? 1
          : (queueResponse[0]['position_in_queue'] as int) + 1;

      final response = await supabase
          .from('court_queues')
          .insert({
            'court_id': courtId,
            'user_id': userId,
            'team_size': teamSize,
            'additional_players': additionalPlayers,
            'status': 'waiting',
            'position_in_queue': nextPosition,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return CourtQueue.fromJson(response);
    } catch (e) {
      print('Error joining queue: $e');
      rethrow;
    }
  }

  // Get queue for a specific court
  static Future<List<CourtQueue>> getCourtQueue(String courtId) async {
    try {
      final response = await supabase
          .from('court_queues')
          .select()
          .eq('court_id', courtId)
          .eq('status', 'waiting')
          .order('position_in_queue', ascending: true);

      return (response as List)
          .map((item) => CourtQueue.fromJson(item))
          .toList();
    } catch (e) {
      print('Error fetching queue: $e');
      return [];
    }
  }

  // Call next player(s) to court
  static Future<CourtQueue?> callNextPlayer(String courtId) async {
    try {
      final queue = await getCourtQueue(courtId);
      if (queue.isEmpty) return null;

      final nextPlayer = queue.first;

      // Update status to called_next
      final response = await supabase
          .from('court_queues')
          .update({
            'status': 'called_next',
            'called_at': DateTime.now().toIso8601String(),
          })
          .eq('id', nextPlayer.id)
          .select()
          .single();

      return CourtQueue.fromJson(response);
    } catch (e) {
      print('Error calling next player: $e');
      rethrow;
    }
  }

  // Check in player to play (confirm they're ready)
  static Future<CourtQueue> checkInPlayer(String queueId) async {
    try {
      final response = await supabase
          .from('court_queues')
          .update({
            'status': 'checked_in',
          })
          .eq('id', queueId)
          .select()
          .single();

      return CourtQueue.fromJson(response);
    } catch (e) {
      print('Error checking in player: $e');
      rethrow;
    }
  }

  // Remove player from queue
  static Future<void> leaveQueue(String queueId) async {
    try {
      await supabase.from('court_queues').delete().eq('id', queueId);
    } catch (e) {
      print('Error leaving queue: $e');
      rethrow;
    }
  }

  // Get next player info for a court
  static Future<CourtQueue?> getNextUp(String courtId) async {
    try {
      final queue = await getCourtQueue(courtId);
      return queue.isNotEmpty ? queue.first : null;
    } catch (e) {
      print('Error getting next up: $e');
      return null;
    }
  }

  // Get waiting count for a court
  static Future<int> getWaitingCount(String courtId) async {
    try {
      final response = await supabase
          .from('court_queues')
          .select('id')
          .eq('court_id', courtId)
          .eq('status', 'waiting');

      return (response as List).length;
    } catch (e) {
      print('Error getting waiting count: $e');
      return 0;
    }
  }
}
