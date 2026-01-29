import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class GameScoringPage extends StatefulWidget {
  final String gameId;

  const GameScoringPage({
    required this.gameId,
    super.key,
  });

  @override
  State<GameScoringPage> createState() => _GameScoringPageState();
}

class _GameScoringPageState extends State<GameScoringPage> {
  Map<String, dynamic>? _court;
  bool _loading = true;
  String? _error;

  int _teamAScore = 0;
  int _teamBScore = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch game session
      final gameSession = await supabase
          .from('game_sessions')
          .select()
          .eq('id', widget.gameId)
          .maybeSingle();

      if (gameSession == null) {
        throw Exception('Game not found');
      }

      // Fetch court details
      final court = await supabase
          .from('courts')
          .select()
          .eq('id', gameSession['court_id'])
          .maybeSingle();

      setState(() {
        _court = court;
        _teamAScore = gameSession['team_a_score'] ?? 0;
        _teamBScore = gameSession['team_b_score'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      print('Error loading game data: $e');
      setState(() {
        _error = 'Error loading game: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateScore(String team, bool increment) async {
    if (increment) {
      if (team == 'A') {
        _teamAScore++;
      } else {
        _teamBScore++;
      }
    } else {
      if (team == 'A' && _teamAScore > 0) {
        _teamAScore--;
      } else if (team == 'B' && _teamBScore > 0) {
        _teamBScore--;
      }
    }
    setState(() {});

    // Auto-save to database
    try {
      await supabase
          .from('game_sessions')
          .update({
            'team_a_score': _teamAScore,
            'team_b_score': _teamBScore,
          })
          .eq('id', widget.gameId);
    } catch (e) {
      print('Error updating score: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving score: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Game?'),
        content: Text(
          'Are you sure you want to end this game? Final score:\nTeam A: $_teamAScore | Team B: $_teamBScore',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('End Game'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _submitting = true);

        // Update game session with final scores and status
        await supabase
            .from('game_sessions')
            .update({
              'team_a_score': _teamAScore,
              'team_b_score': _teamBScore,
              'status': 'completed',
              'ended_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.gameId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Game ended and scores saved!'),
              backgroundColor: Colors.green,
            ),
          );
          // Go back to referee courts
          context.go('/referee-courts');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending game: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _submitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Game Scoring')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Game Scoring')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(_error ?? 'Error'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadGameData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_court?['name'] ?? 'Game Scoring'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game info card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'LIVE GAME',
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _court?['name'] ?? 'Court',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: cs.onSurfaceVariant),
                        SizedBox(width: 4),
                        Text(
                          _court?['city'] ?? 'Unknown',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Score display
            Row(
              children: [
                // Team A
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Team A',
                          style: tt.labelMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '$_teamAScore',
                          style: tt.displayMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _updateScore('A', false),
                              icon: Icon(Icons.remove),
                              label: Text(''),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _updateScore('A', true),
                              icon: Icon(Icons.add),
                              label: Text(''),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Team B
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.secondary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Team B',
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '$_teamBScore',
                          style: tt.displayMedium?.copyWith(
                            color: cs.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _updateScore('B', false),
                              icon: Icon(Icons.remove),
                              label: Text(''),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _updateScore('B', true),
                              icon: Icon(Icons.add),
                              label: Text(''),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // End game button
            FilledButton.icon(
              onPressed: _submitting ? null : _endGame,
              icon: Icon(Icons.stop_circle),
              label: Text('End Game & Save Scores'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
