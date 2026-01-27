import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/notification.dart';

final supabase = Supabase.instance.client;

class NotificationService {
  // Create a notification
  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Get user notifications
  static Future<List<AppNotification>> getUserNotifications({
    int limit = 50,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final query = supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await query;
      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .is_('read_at', null)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Subscribe to unread count changes
  static Stream<int> subscribeToUnreadCount() async* {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        yield 0;
        return;
      }

      await for (final _ in supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)) {
        final count = await getUnreadCount();
        yield count;
      }
    } catch (e) {
      print('Error in unread count subscription: $e');
      yield 0;
    }
  }
}
