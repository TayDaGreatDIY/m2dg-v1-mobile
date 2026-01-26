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
  GameSession? _game;
  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];

  int _teamAScore = 0;
  int _teamBScore = 0;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    setState(() => _loading = true);

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
      }

      setState(() => _loading = false);
    } catch (e) {
      print('Error loading game: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _updateScore() async {
    if (_game == null) return;

    try {
      await GameSessionService.updateScore(
        gameId: _game!.id,
        teamAScore: _teamAScore,
        teamBScore: _teamBScore,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Score updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating score: $e')),
        );
      }
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

    try {
      await GameSessionService.endGame(
        gameId: _game!.id,
        winnerTeam: winnerTeam,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game ended! Stats updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Game'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _game == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_basketball, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No active game',
                        style: Theme.of(context).textTheme.titleLarge,
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
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                            onIncrement: () => setState(() => _teamAScore++),
                            onDecrement: () => setState(() {
                              if (_teamAScore > 0) _teamAScore--;
                            }),
                          ),
                          const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _ScoreCard(
                            team: 'Team B',
                            score: _teamBScore,
                            color: Colors.red,
                            onIncrement: () => setState(() => _teamBScore++),
                            onDecrement: () => setState(() {
                              if (_teamBScore > 0) _teamBScore--;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Update Score Button
                      FilledButton.icon(
                        onPressed: _updateScore,
                        icon: const Icon(Icons.save),
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _endGame('team_a'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text('Team A Wins'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _endGame('team_b'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Team B Wins'),
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
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ScoreCard({
    required this.team,
    required this.score,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
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
