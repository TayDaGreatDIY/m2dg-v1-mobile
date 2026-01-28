import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/notification_service.dart';

final supabase = Supabase.instance.client;

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({
    required this.child,
    super.key,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  String? _userRole;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadUnreadCount();
    _setupNotificationListener();
  }

  Future<void> _loadUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await supabase
          .from('profiles')
          .select('user_role')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userRole = profile['user_role'] as String? ?? 'athlete';
          _loadingRole = false;
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'athlete';
          _loadingRole = false;
        });
      }
    }
  }

  void _loadUnreadCount() async {
    try {
      final notifications = await NotificationService.getUserNotifications(limit: 100);
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((n) => !n.isRead).length;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _setupNotificationListener() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _loadUnreadCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _loadUnreadCount(),
        )
        .subscribe();
  }

  void _onNavTapped(int index) {
    // Record user activity for session timeout
    sessionManager.recordActivity();
    
    setState(() => _selectedIndex = index);

    final isReferee = _userRole == 'referee';

    switch (index) {
      case 0:
        context.go('/');
      case 1:
        // Challenges for athletes, Requests for referees
        context.go(isReferee ? '/referee-requests' : '/challenges');
      case 2:
        context.go('/leaderboard');
      case 3:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReferee = _userRole == 'referee';

    // Update selected index based on current route
    final location = GoRouterState.of(context).matchedLocation;
    final newIndex = switch (location) {
      '/challenges' || '/referee-requests' || '/create-challenge' || '/challenge/:id' || '/opponent-search' =>
        1,
      '/leaderboard' => 2,
      '/profile' => 3,
      _ => 0, // courts
    };

    if (newIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIndex = newIndex);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('M2DG'),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.sports_basketball),
                onPressed: () {
                  context.push('/notifications');
                  // Reload count after viewing notifications
                  Future.delayed(const Duration(milliseconds: 500), _loadUnreadCount);
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => sessionManager.recordActivity(),
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.location_on_outlined),
            activeIcon: const Icon(Icons.location_on),
            label: isReferee ? 'Courts' : 'Courts',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sports_basketball_outlined),
            activeIcon: const Icon(Icons.sports_basketball),
            label: isReferee ? 'Requests' : 'Challenges',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.leaderboard_outlined),
            activeIcon: const Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outlined),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
