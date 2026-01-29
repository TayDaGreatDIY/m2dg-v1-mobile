import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';
import 'dart:async';

final supabase = Supabase.instance.client;

class GameWaitingPage extends StatefulWidget {
  final String challengeId;

  const GameWaitingPage({required this.challengeId, super.key});

  @override
  State<GameWaitingPage> createState() => _GameWaitingPageState();
}

class _GameWaitingPageState extends State<GameWaitingPage> {
  late Future<Challenge> _challengeFuture;
  Challenge? _challenge;
  Timer? _countdownTimer;
  Duration _timeUntilStart = Duration.zero;
  String _status = 'loading';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
    _setupCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setupCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_challenge?.scheduledStartTime == null) return;

      final now = DateTime.now();
      final startTime = _challenge!.scheduledStartTime!;
      final difference = startTime.difference(now);

      setState(() {
        _timeUntilStart = difference;

        if (difference.isNegative) {
          _status = 'started';
        } else if (difference.inMinutes >= 1) {
          _status = 'waiting';
        } else {
          _status = 'imminent';
        }
      });
    });
  }

  Future<void> _setPlayerReady() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isProcessing = true);
    try {
      await ChallengeService.setPlayerReady(widget.challengeId, userId, true);
      
      // Fetch updated challenge data
      final updatedChallenge = await ChallengeService.fetchChallenge(widget.challengeId);
      
      if (mounted) {
        setState(() {
          _challenge = updatedChallenge;
          _challengeFuture = Future.value(updatedChallenge);
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ You are ready!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _requestReferee() async {
    try {
      await ChallengeService.requestReferee(widget.challengeId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📣 Referee request sent to all registered referees!'),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Ready'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Challenge>(
        future: _challengeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❌ Error loading challenge'),
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
            return const Center(child: Text('Challenge not found'));
          }

          if (_challenge == null) {
            _challenge = challenge;
            if (_challenge!.scheduledStartTime != null) {
              _setupCountdown();
            }
          }

          final userId = supabase.auth.currentUser?.id;
          final isCreator = challenge.creatorId == userId;
          final isPlayerReady =
              isCreator ? challenge.creatorReady : challenge.opponentReady;
          final isOpponentReady =
              isCreator ? challenge.opponentReady : challenge.creatorReady;
          final bothReady = challenge.creatorReady && challenge.opponentReady;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Countdown timer
                  if (challenge.scheduledStartTime != null) ...[
                    Card(
                      color: cs.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Time to Game',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatCountdown(_timeUntilStart),
                              style: tt.displayMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _status == 'started'
                                  ? '🎮 Game has started!'
                                  : _status == 'imminent'
                                      ? '⚠️  Game starts soon!'
                                      : '⏱️  Waiting for game time',
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Challenge participants
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Players',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Creator
                          FutureBuilder<String>(
                            future: ChallengeService.fetchOpponentName(
                                challenge.creatorId),
                            builder: (context, nameSnapshot) {
                              final creatorName = nameSnapshot.data ?? 'Creator';
                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: cs.primary,
                                    child: Text(
                                      creatorName.substring(0, 1).toUpperCase(),
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          creatorName,
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Creator',
                                          style: tt.labelSmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (challenge.creatorReady)
                                    Chip(
                                      label: const Text('✅ Ready'),
                                      backgroundColor:
                                          Colors.green.withValues(alpha: 0.3),
                                      labelStyle: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    Chip(
                                      label: const Text('⏳ Not Ready'),
                                      backgroundColor: cs.surfaceContainerHigh,
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Opponent
                          if (challenge.opponentId != null)
                            FutureBuilder<String>(
                              future: ChallengeService.fetchOpponentName(
                                  challenge.opponentId!),
                              builder: (context, nameSnapshot) {
                                final opponentName =
                                    nameSnapshot.data ?? 'Opponent';
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: cs.secondary,
                                      child: Text(
                                        opponentName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opponentName,
                                            style: tt.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Opponent',
                                            style: tt.labelSmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (challenge.opponentReady)
                                      Chip(
                                        label: const Text('✅ Ready'),
                                        backgroundColor: Colors.green
                                            .withValues(alpha: 0.3),
                                        labelStyle: TextStyle(
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else
                                      Chip(
                                        label: const Text('⏳ Not Ready'),
                                        backgroundColor:
                                            cs.surfaceContainerHigh,
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status message
                  if (bothReady)
                    Card(
                      color: Colors.green.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green[700], size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Both Players Ready!',
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  Text(
                                    'Go to court and start the game',
                                    style: tt.labelSmall?.copyWith(
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: cs.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          isOpponentReady
                              ? '⏳ Waiting on you to ready up!'
                              : '⏳ Waiting on opponent to ready up...',
                          style: tt.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (!isPlayerReady)
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _setPlayerReady,
                      icon: _isProcessing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('I\'m Ready!'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.sports_basketball),
                      label: const Text('Ready'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _requestReferee,
                    icon: const Icon(Icons.gavel),
                    label: const Text('Request Referee'),
                  ),
                  if (challenge.refereeRequested)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Chip(
                        label: const Text('📣 Referee request sent'),
                        backgroundColor: cs.primaryContainer,
                        labelStyle: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
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
