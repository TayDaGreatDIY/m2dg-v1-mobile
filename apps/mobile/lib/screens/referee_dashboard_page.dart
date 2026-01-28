import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/services/referee_service.dart';

final supabase = Supabase.instance.client;

class RefereeDashboardPage extends StatefulWidget {
  const RefereeDashboardPage({super.key});

  @override
  State<RefereeDashboardPage> createState() => _RefereeDashboardPageState();
}

class _RefereeDashboardPageState extends State<RefereeDashboardPage> {
  late Future<List<Map<String, dynamic>>> _pendingGamesFuture;

  @override
  void initState() {
    super.initState();
    final refereeId = supabase.auth.currentUser?.id;
    if (refereeId != null) {
      _pendingGamesFuture = RefereeService.getPendingRefereeGames(refereeId);
    }
  }

  Future<void> _acceptGame(String assignmentId) async {
    try {
      await RefereeService.acceptRefereeAssignment(assignmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You accepted! Referee instructions sent.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          final refereeId = supabase.auth.currentUser?.id;
          if (refereeId != null) {
            _pendingGamesFuture = RefereeService.getPendingRefereeGames(refereeId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineGame(String assignmentId) async {
    try {
      await RefereeService.declineRefereeAssignment(assignmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Declined. You can still accept other games.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          final refereeId = supabase.auth.currentUser?.id;
          if (refereeId != null) {
            _pendingGamesFuture = RefereeService.getPendingRefereeGames(refereeId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return 'Started';
    } else if (difference.inMinutes < 1) {
      return 'Starting now!';
    } else if (difference.inHours < 1) {
      return 'In ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return 'In ${difference.inDays} days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏀 Referee Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingGamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❌ Error loading games',
                      style: tt.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      final refereeId = supabase.auth.currentUser?.id;
                      if (refereeId != null) {
                        _pendingGamesFuture =
                            RefereeService.getPendingRefereeGames(refereeId);
                      }
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final games = snapshot.data ?? [];

          if (games.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⏳ No pending games',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 8),
                  Text('You\'ll see games here when teams need a referee',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: games.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final game = games[index];
              final challenge = game['challenges'] as Map<String, dynamic>?;
              final court = challenge?['courts'] as Map<String, dynamic>?;
              final scheduledTime = challenge?['scheduled_start_time'] != null
                  ? DateTime.parse(challenge!['scheduled_start_time'] as String)
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with type and time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Type: ${challenge?['challenge_type']?.toString().toUpperCase() ?? 'N/A'}',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (court != null)
                                  Text(
                                    'Court: ${court['name'] ?? 'Unknown'}',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              _formatTime(scheduledTime),
                              style: tt.labelSmall,
                            ),
                            backgroundColor: cs.primaryContainer,
                            labelStyle: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Request message
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📣 Professional Assistance Needed',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A game is looking to start soon and needs your professional assistance.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _declineGame(game['id'] as String),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _acceptGame(game['id'] as String),
                              icon: const Icon(Icons.gavel),
                              label: const Text('Accept & Referee'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
