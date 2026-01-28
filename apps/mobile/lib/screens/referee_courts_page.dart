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

      // Fetch active games with court and player information
      final response = await supabase
          .from('game_sessions')
          .select(
              'id, court_id, status, team_a_score, team_b_score, started_at, courts(id, name, city, location), game_session_players(user_id)')
          .inFilter('status', ['active', 'in_progress'])
          .order('started_at', ascending: false);

      // Fetch all player profiles to display names
      final games = (response as List).cast<Map<String, dynamic>>();
      
      // Get all unique user IDs from all games
      final allPlayerIds = <String>{};
      for (var game in games) {
        final players = (game['game_session_players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (var player in players) {
          final userId = player['user_id'] as String?;
          if (userId != null) allPlayerIds.add(userId);
        }
      }

      // Fetch profiles for all players in one query
      Map<String, Map<String, dynamic>> profilesMap = {};
      if (allPlayerIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('user_id, username, display_name')
            .inFilter('user_id', allPlayerIds.toList());
        
        for (var profile in profiles as List) {
          profilesMap[profile['user_id'] as String] = profile;
        }
      }

      // Attach profile data to each game
      for (var game in games) {
        final players = (game['game_session_players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (var player in players) {
          final userId = player['user_id'] as String?;
          if (userId != null && profilesMap.containsKey(userId)) {
            player['profile'] = profilesMap[userId];
          }
        }
      }

      setState(() {
        _activeGames = games;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading active games: $e');
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
            Text('No active games right now', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Check back soon!', style: tt.bodySmall),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Games'),
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
            final players = (game['game_session_players'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            // Extract player names from profiles
            final playerNames = players
                .map((p) {
                  final profile = p['profile'] as Map<String, dynamic>?;
                  return profile?['display_name'] ?? profile?['username'] ?? 'Unknown Player';
                })
                .toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Court name and location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court?['name'] ?? 'Unknown Court',
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    court?['city'] ?? 'Unknown Location',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'LIVE',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.green[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Players Playing
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Players', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (playerNames.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: playerNames.map((name) {
                                return Chip(
                                  label: Text(name, style: tt.bodySmall),
                                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                                );
                              }).toList(),
                            )
                          else
                            Text('No players loaded', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Score and Timer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Score
                          Column(
                            children: [
                              Text(
                                '$team1Score - $team2Score',
                                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text('Current Score', style: tt.labelSmall),
                            ],
                          ),
                          // Time elapsed
                          if (startedAt != null)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.timer, size: 16, color: cs.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getCountdownTime(startedAt),
                                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text('Elapsed', style: tt.labelSmall),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ref Game Button (only action button)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.sports_baseball),
                        label: const Text('Ref Game'),
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
