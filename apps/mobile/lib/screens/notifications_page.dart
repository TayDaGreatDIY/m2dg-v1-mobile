import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/models/notification.dart';
import 'package:mobile/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    _notifications = await NotificationService.getUserNotifications();
    setState(() => _loading = false);
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService.markAsRead(id);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    _loadNotifications();
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationService.deleteNotification(id);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteNotification(notification.id),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: notification.isRead
                              ? null
                              : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getNotificationColor(notification.type),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notification.message),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(notification.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: !notification.isRead
                                ? IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () => _markAsRead(notification.id),
                                    tooltip: 'Mark as read',
                                  )
                                : null,
                            isThreeLine: true,
                            onTap: () {
                              if (!notification.isRead) {
                                _markAsRead(notification.id);
                              }
                              // Handle notification tap based on type
                              _handleNotificationTap(notification);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'queue_update':
        return Colors.blue;
      case 'game_invite':
        return Colors.green;
      case 'friend_request':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'queue_update':
        return Icons.play_arrow;
      case 'game_invite':
        return Icons.sports_basketball;
      case 'friend_request':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  void _handleNotificationTap(AppNotification notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case 'message':
        // Navigate to messages page with sender ID
        if (notification.data != null && notification.data!.containsKey('senderId')) {
          final senderId = notification.data!['senderId'] as String;
          context.go('/messages/$senderId');
        }
        break;
      case 'friend_request':
        // Navigate to social/friends page
        context.go('/social');
        break;
      case 'challenge':
        // Navigate to challenges page
        context.go('/challenges');
        break;
      case 'game_result':
        // Navigate to leaderboard
        context.go('/leaderboard');
        break;
      case 'queue_update':
        // Navigate to courts list
        context.go('/');
        break;
      default:
        // Default: stay on notifications page
        break;
    }
  }
}
