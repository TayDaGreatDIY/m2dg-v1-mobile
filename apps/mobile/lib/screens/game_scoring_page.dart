import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';

final supabase = Supabase.instance.client;

class GameScoringPage extends StatefulWidget {
  final String challengeId;

  const GameScoringPage({required this.challengeId, super.key});

  @override
  State<GameScoringPage> createState() => _GameScoringPageState();
}

class _GameScoringPageState extends State<GameScoringPage> {
  late Future<Challenge> _challengeFuture;
  int _creatorScore = 0;
  int _opponentScore = 0;
  String? _winnerMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
  }

  Future<void> _submitScore() async {
    if (_creatorScore == 0 && _opponentScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️  Please enter scores')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Update game session with scores
      // This would call your GameSessionService to record the final score
      final winner = _creatorScore > _opponentScore ? 'creator' : 'opponent';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Score recorded! Winner: ${winner.toUpperCase()}'),
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _winnerMessage = '🏆 Game Over!\n${winner.toUpperCase()} wins ${_creatorScore.toString().padLeft(2, '0')} - ${_opponentScore.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏀 Game Scoring'),
        centerTitle: true,
      ),
      body: FutureBuilder<Challenge>(
        future: _challengeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❌ Error loading game'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _challengeFuture =
                          ChallengeService.fetchChallenge(widget.challengeId);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final challenge = snapshot.data;
          if (challenge == null) {
            return const Center(child: Text('Game not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_winnerMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _winnerMessage!,
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Game Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Game Type',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.challengeType.toUpperCase(),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Score Input
                Text(
                  'Final Score',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    // Creator Score
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Creator',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: _winnerMessage != null
                                      ? null
                                      : () => setState(() {
                                            if (_creatorScore > 0) _creatorScore--;
                                          }),
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  _creatorScore.toString().padLeft(2, '0'),
                                  style: tt.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _winnerMessage != null
                                      ? null
                                      : () => setState(() => _creatorScore++),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // VS
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'VS',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Opponent Score
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Opponent',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: _winnerMessage != null
                                      ? null
                                      : () => setState(() {
                                            if (_opponentScore > 0) _opponentScore--;
                                          }),
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  _opponentScore.toString().padLeft(2, '0'),
                                  style: tt.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _winnerMessage != null
                                      ? null
                                      : () => setState(() => _opponentScore++),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                FilledButton(
                  onPressed: _isSubmitting || _winnerMessage != null
                      ? null
                      : _submitScore,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Final Score'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
