import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

final supabase = Supabase.instance.client;

class RefereeRequestsPage extends StatefulWidget {
  const RefereeRequestsPage({super.key});

  @override
  State<RefereeRequestsPage> createState() => _RefereeRequestsPageState();
}

class _RefereeRequestsPageState extends State<RefereeRequestsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _refereeRequests = [];
  String? _error;
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRefereeRequests();
    // Refresh every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) _loadRefereeRequests();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _loadRefereeRequests() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch referee request notifications for this user
      final notifications = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('type', 'referee_request')
          .isFilter('read_at', null)
          .order('created_at', ascending: false);

      // Fetch court and challenge details for each request
      List<Map<String, dynamic>> requests = [];
      for (var notif in notifications as List) {
        try {
          final challengeId = notif['data']?['challenge_id'];
          if (challengeId != null) {
            final challenge = await supabase
                .from('challenges')
                .select()
                .eq('id', challengeId)
                .maybeSingle();

            if (challenge != null) {
              final court = await supabase
                  .from('courts')
                  .select('id, name, city')
                  .eq('id', challenge['court_id'])
                  .maybeSingle();

              // Get player names
              final creator = await supabase
                  .from('profiles')
                  .select('username')
                  .eq('user_id', challenge['creator_id'])
                  .maybeSingle();

              requests.add({
                'notification_id': notif['id'],
                'challenge_id': challengeId,
                'court_name': court?['name'] ?? 'Unknown Court',
                'city': court?['city'] ?? 'Unknown',
                'player_name': creator?['username'] ?? 'Unknown Player',
                'created_at': notif['created_at'],
              });
            }
          }
        } catch (e) {
          print('Error fetching request details: $e');
        }
      }

      setState(() {
        _refereeRequests = requests;
        _loading = false;
      });
    } catch (e) {
      print('Error loading referee requests: $e');
      setState(() {
        _error = 'Error loading requests: $e';
        _loading = false;
      });
    }
  }

  Future<void> _acceptRequest(String challengeId, String notificationId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Update challenge with assigned_referee_id
      await supabase
          .from('challenges')
          .update({'assigned_referee_id': userId})
          .eq('id', challengeId);

      // Mark notification as read
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      // Get challenge details to notify players
      final challenge = await supabase
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();

      // Notify both players
      for (var playerId in [challenge['creator_id'], challenge['opponent_id']]) {
        if (playerId != null) {
          await supabase.from('notifications').insert({
            'user_id': playerId,
            'type': 'referee_accepted',
            'title': '✓ Referee Ready',
            'message': 'Referee has been assigned to your game',
            'data': {'challenge_id': challengeId},
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Referee assignment confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRefereeRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String notificationId) async {
    try {
      // Mark notification as read
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request declined'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRefereeRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referee Requests'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error ?? 'Error loading requests'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRefereeRequests,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _refereeRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: cs.onSurfaceVariant),
                          SizedBox(height: 16),
                          Text(
                            'No Referee Requests',
                            style: tt.titleLarge,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You\'ll see referee requests here',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: _refereeRequests.length,
                      itemBuilder: (context, index) {
                        final request = _refereeRequests[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with court info
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.gavel,
                                        color: cs.primary,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request['court_name'] ?? 'Court',
                                            style: tt.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 14,
                                                  color: cs.onSurfaceVariant),
                                              SizedBox(width: 4),
                                              Text(
                                                request['city'] ?? 'Unknown',
                                                style: tt.labelSmall?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),

                                // Player info
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person,
                                          size: 20, color: cs.onSurfaceVariant),
                                      SizedBox(width: 8),
                                      Text(
                                        'Player: ${request['player_name'] ?? 'Unknown'}',
                                        style: tt.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Action buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _acceptRequest(
                                          request['challenge_id'],
                                          request['notification_id'],
                                        ),
                                        icon: Icon(Icons.check_circle),
                                        label: Text('Accept'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _declineRequest(request['notification_id']),
                                        icon: Icon(Icons.close),
                                        label: Text('Decline'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
