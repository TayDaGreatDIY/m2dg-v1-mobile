import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages user session timeouts based on inactivity.
/// Auto-signs out user after [inactivityTimeout] of no activity.
class SessionManager {
  final SupabaseClient supabase;
  
  /// Default: 30 minutes of inactivity before logout
  final Duration inactivityTimeout;
  
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;

  SessionManager({
    required this.supabase,
    this.inactivityTimeout = const Duration(minutes: 30),
  });

  /// Start monitoring for inactivity.
  /// Call this once at app startup in main.dart.
  void startMonitoring() {
    _resetInactivityTimer();
    print('🔐 SESSION: Monitoring started (timeout: ${inactivityTimeout.inMinutes} min)');
  }

  /// Record user activity (touch, navigation, etc.)
  /// Call this from screens/widgets to track user engagement.
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _resetInactivityTimer();
  }

  /// Cancel monitoring and clean up.
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();

    _inactivityTimer = Timer(inactivityTimeout, () async {
      print('🔐 SESSION: Inactivity timeout reached. Signing out.');
      try {
        await supabase.auth.signOut();
        print('🔐 SESSION: User signed out due to inactivity');
      } catch (e) {
        print('🔐 SESSION: Error during auto-signout: $e');
      }
    });
  }

  /// Get remaining time until logout (for UI display if needed)
  Duration? getRemainingTime() {
    if (_lastActivityTime == null) return null;
    
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    final remaining = inactivityTimeout - elapsed;
    
    return remaining > Duration.zero ? remaining : Duration.zero;
  }
}
