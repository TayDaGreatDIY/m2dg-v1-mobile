import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/game_session.dart';
import 'package:mobile/services/game_session_service.dart';

class ActiveGamePage extends StatefulWidget {
  final String courtId;
  final String? gameId;

  const ActiveGamePage({
    super.key,
    required this.courtId,
    this.gameId,
  });

  @override
  State<ActiveGamePage> createState() => _ActiveGamePageState();
}

class _ActiveGamePageState extends State<ActiveGamePage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  GameSession? _game;
  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];

  int _teamAScore = 0;
  int _teamBScore = 0;
  bool _isUpdating = false;

  late RealtimeChannel _gameChannel;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _gameChannel.unsubscribe();
    super.dispose();
  }

  Future<void> _loadGame() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      GameSession? game;
      
      if (widget.gameId != null) {
        final response = await supabase
            .from('game_sessions')
            .select()
            .eq('id', widget.gameId!)
            .single();
        game = GameSession.fromJson(response);
      } else {
        game = await GameSessionService.getActiveGame(widget.courtId);
      }

      if (game != null) {
        _game = game;
        _teamAScore = game.teamAScore;
        _teamBScore = game.teamBScore;

        // Load players
        final players = await supabase
            .from('game_session_players')
            .select('*, profiles(*)')
            .eq('game_session_id', game.id)
            .order('position', ascending: true);

        _teamAPlayers = (players as List)
            .where((p) => p['team'] == 'team_a')
            .toList()
            .cast<Map<String, dynamic>>();
            
        _teamBPlayers = (players as List)
            .where((p) => p['team'] == 'team_b')
            .toList()
            .cast<Map<String, dynamic>>();

        // Setup real-time subscription
        if (mounted) {
          _setupGameSubscription(game.id);
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      print('❌ Error loading game: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setupGameSubscription(String gameId) {
    try {
      _gameChannel = supabase
          .channel('game:$gameId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'game_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: gameId,
            ),
            callback: (payload) {
              if (mounted) {
                final updated = GameSession.fromJson(payload.newRecord);
                setState(() {
                  _game = updated;
                  _teamAScore = updated.teamAScore;
                  _teamBScore = updated.teamBScore;
                });
                
                // Show snackbar if game ended
                if (updated.status == 'completed') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Game completed! ${updated.winnerTeam == 'team_a' ? 'Team A' : 'Team B'} wins!'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) Navigator.pop(context);
                  });
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      print('⚠️  Error setting up game subscription: $e');
    }
  }

  Future<void> _updateScore() async {
    if (_game == null) return;

    setState(() => _isUpdating = true);
    try {
      await GameSessionService.updateScore(
        gameId: _game!.id,
        teamAScore: _teamAScore,
        teamBScore: _teamBScore,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Score updated'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error updating score: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _endGame(String winnerTeam) async {
    if (_game == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game'),
        content: Text('Confirm ${winnerTeam == 'team_a' ? 'Team A' : 'Team B'} wins?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    try {
      await GameSessionService.endGame(
        gameId: _game!.id,
        winnerTeam: winnerTeam,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Game ended! Stats updated.'), duration: Duration(seconds: 2)),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error ending game: $e')),
        );
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Game'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: cs.error),
                      const SizedBox(height: 16),
                      Text('Error loading game', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadGame,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _game == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_basketball_outlined, size: 64, color: cs.outlineVariant),
                          const SizedBox(height: 16),
                          Text('No active game', style: tt.titleMedium),
                          const SizedBox(height: 8),
                          Text('No game in progress at this court', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadGame,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Game Type
                          Chip(
                            label: Text(_game!.challengeType.toUpperCase()),
                            backgroundColor: cs.primaryContainer,
                            labelStyle: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Score Display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ScoreCard(
                                team: 'Team A',
                                score: _teamAScore,
                                color: Colors.blue,
                                onIncrement: _isUpdating ? null : () => setState(() => _teamAScore++),
                                onDecrement: _isUpdating
                                    ? null
                                    : () => setState(() {
                                          if (_teamAScore > 0) _teamAScore--;
                                        }),
                              ),
                              Text(
                                'VS',
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _ScoreCard(
                                team: 'Team B',
                                score: _teamBScore,
                                color: Colors.red,
                                onIncrement: _isUpdating ? null : () => setState(() => _teamBScore++),
                                onDecrement: _isUpdating
                                    ? null
                                    : () => setState(() {
                                          if (_teamBScore > 0) _teamBScore--;
                                        }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Update Score Button
                          FilledButton.icon(
                            onPressed: _isUpdating ? null : _updateScore,
                            icon: _isUpdating ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ) : const Icon(Icons.save),
                            label: const Text('Update Score'),
                          ),
                          const SizedBox(height: 32),

                          // Team A Players
                          _TeamSection(
                            title: 'Team A',
                            players: _teamAPlayers,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 24),

                          // Team B Players
                          _TeamSection(
                            title: 'Team B',
                            players: _teamBPlayers,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 32),

                          // End Game Buttons
                          if (_game!.status == 'active') ...[
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'End Game',
                              style: tt.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isUpdating ? null : () => _endGame('team_a'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    child: _isUpdating
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Team A Wins'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isUpdating ? null : () => _endGame('team_b'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: _isUpdating
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Team B Wins'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String team;
  final int score;
  final Color color;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _ScoreCard({
    required this.team,
    required this.score,
    required this.color,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              team,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$score',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove),
                  style: IconButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> players;
  final Color color;

  const _TeamSection({
    required this.title,
    required this.players,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...players.map((player) {
          final profile = player['profiles'];
          final displayName = profile?['display_name'] ?? 
              profile?['username'] ?? 
              'Player ${player['position']}';
          
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Text(
                  '${player['position']}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(displayName),
            ),
          );
        }),
      ],
    );
  }
}
