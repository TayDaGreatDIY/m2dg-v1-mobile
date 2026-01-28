import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RefereeCourtsPage extends StatefulWidget {
  const RefereeCourtsPage({super.key});

  @override
  State<RefereeCourtsPage> createState() => _RefereeCourtsPageState();
}

class _RefereeCourtsPageState extends State<RefereeCourtsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _activeGames = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActiveGames();
  }

  Future<void> _loadActiveGames() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch games that are looking for referees or currently active
      final response = await supabase
          .from('game_sessions')
          .select(
              'id, court_id, status, team_a_score, team_b_score, started_at, courts(id, name, city, location)')
          .inFilter('status', ['active', 'in_progress'])
          .order('started_at', ascending: false);

      setState(() {
        _activeGames = (response as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      print('Error loading active games: $e');
      setState(() {
        _error = 'Error loading games: $e';
        _loading = false;
      });
    }
  }

  String _getCountdownTime(String? startedAt) {
    if (startedAt == null) return '--:--';
    try {
      final gameTime = DateTime.parse(startedAt);
      final now = DateTime.now();
      final elapsed = now.difference(gameTime);
      final minutes = elapsed.inMinutes;
      final seconds = (elapsed.inSeconds % 60);
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  Future<void> _workGame(String gameId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated')),
        );
        return;
      }

      // Update the game_sessions table with the current user as assigned_referee_id
      await supabase
          .from('game_sessions')
          .update({'assigned_referee_id': userId})
          .eq('id', gameId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined as referee!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Reload the list to reflect changes
      _loadActiveGames();
    } catch (e) {
      print('Error joining as referee: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining game: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadActiveGames,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_activeGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_basketball, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No active games looking for referees',
                style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Check back soon!', style: tt.bodySmall),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts Looking for Referees'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveGames,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _activeGames.length,
          itemBuilder: (context, index) {
            final game = _activeGames[index];
            final court = game['courts'] as Map<String, dynamic>?;
            final status = game['status'] as String;
            final team1Score = game['team_a_score'] ?? 0;
            final team2Score = game['team_b_score'] ?? 0;
            final startedAt = game['started_at'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Court name and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court?['name'] ?? 'Unknown Court',
                                style: tt.titleSmall,
                              ),
                              Text(
                                court?['city'] ?? 'Unknown Location',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'waiting_for_referee'
                                ? Colors.orange[200]
                                : Colors.green[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: tt.labelSmall?.copyWith(
                              color: status == 'waiting_for_referee'
                                  ? Colors.orange[900]
                                  : Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Score Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Score
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '$team1Score',
                                    style: tt.displayMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                  Text(
                                    'Team 1',
                                    style: tt.bodySmall,
                                  ),
                                ],
                              ),
                              Text(
                                'vs',
                                style: tt.titleMedium,
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$team2Score',
                                    style: tt.displayMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.tertiary,
                                    ),
                                  ),
                                  Text(
                                    'Team 2',
                                    style: tt.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Countdown Timer
                          if (startedAt != null) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer,
                                    size: 18, color: cs.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Elapsed: ${_getCountdownTime(startedAt)}',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.sports_baseball),
                        label: const Text('Work Game'),
                        onPressed: () {
                          _workGame(game['id']);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
