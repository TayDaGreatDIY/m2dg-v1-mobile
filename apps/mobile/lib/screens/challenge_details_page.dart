import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';
import 'package:mobile/services/developer_mode_service.dart';
import 'package:mobile/services/game_session_service.dart';

final supabase = Supabase.instance.client;

class ChallengeDetailsPage extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailsPage({required this.challengeId, super.key});

  @override
  State<ChallengeDetailsPage> createState() => _ChallengeDetailsPageState();
}

class _ChallengeDetailsPageState extends State<ChallengeDetailsPage> {
  late Future<Challenge> _challengeFuture;
  Challenge? _challenge;
  String? _selectedScoringMethod;
  bool _agreeToScoring = false;
  bool _isProcessing = false;
  bool _isCreator = false;
  String? _courtName;
  bool _isDevMode = false;

  Future<String> _fetchCourtName(String courtId) async {
    if (_courtName != null) return _courtName!;
    
    try {
      final court = await supabase
          .from('courts')
          .select('name')
          .eq('id', courtId)
          .maybeSingle();
      
      final name = court?['name'] as String? ?? 'Unknown Court';
      setState(() => _courtName = name);
      return name;
    } catch (e) {
      print('Error fetching court name: $e');
      return 'Unknown Court';
    }
  }

  Future<void> _approveChallenge() async {
    setState(() => _isProcessing = true);
    try {
      await ChallengeService.approveChallenge(widget.challengeId);
      if (!mounted) return;

      setState(() {
        _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge approved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving challenge: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
    _loadDevMode();
  }

  Future<void> _loadDevMode() async {
    final isDev = await DeveloperModeService.isDeveloperMode();
    setState(() => _isDevMode = isDev);
  }

  Future<void> _acceptChallenge() async {
    setState(() => _isProcessing = true);
    try {
      await ChallengeService.acceptChallenge(widget.challengeId);
      if (!mounted) return;
      
      setState(() {
        _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge accepted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineChallenge() async {
    setState(() => _isProcessing = true);
    try {
      await ChallengeService.declineChallenge(widget.challengeId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _agreeToScoringMethod(String method, bool isCreator) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isProcessing = true);
    try {
      await ChallengeService.agreeToScoringMethod(
        widget.challengeId,
        method,
        isCreator,
      );
      if (!mounted) return;

      setState(() {
        _selectedScoringMethod = method;
        _agreeToScoring = true;
        _challengeFuture = ChallengeService.fetchChallenge(widget.challengeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agreed to $method')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startGame(Challenge challenge) async {
    setState(() => _isProcessing = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Determine creator and opponent
      final isCreator = challenge.creatorId == userId;
      final creatorId = challenge.creatorId;
      final opponentId = challenge.opponentId!;

      // Import GameSessionService
      final game = await GameSessionService.startGameFromChallenge(
        challengeId: challenge.id,
        courtId: challenge.courtId,
        creatorId: creatorId,
        opponentId: opponentId,
        challengeType: challenge.challengeType,
      );

      if (!mounted) return;
      
      // Navigate to active game page
      context.go('/active-game/${game.id}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Game started!'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error starting game: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Details'),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final challenge = snapshot.data;
          if (challenge == null) {
            return const Center(child: Text('Challenge not found'));
          }

          // Update state with challenge and creator flag
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_challenge?.id != challenge.id) {
              setState(() {
                _challenge = challenge;
                _isCreator = challenge.creatorId == userId;
              });
            }
          });

          final isCreator = challenge.creatorId == userId;
          final isPending = challenge.status == 'pending_approval';
          final isOpen = challenge.status == 'open';
          final isAccepted = challenge.status == 'accepted';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          challenge.status.toUpperCase(),
                          style: tt.labelLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        if (isPending && isCreator)
                          Text(
                            '⏳ Pending Admin Approval',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Challenge type & court
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Challenge Type',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            challenge.challengeType.toUpperCase(),
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Court',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          FutureBuilder<String>(
                            future: _fetchCourtName(challenge.courtId),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? 'Loading...',
                                style: tt.bodyLarge,
                              );
                            },
                          ),
                          if (challenge.hasWager) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Wager',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '\$${challenge.wagerAmount?.toStringAsFixed(2) ?? '0.00'}',
                              style: tt.titleMedium?.copyWith(
                                color: cs.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scoring method
                  if (isAccepted || (isOpen && !isCreator))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scoring Method',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                RadioListTile(
                                  title: const Text('Self-Ref (We count score)'),
                                  value: 'self_ref',
                                  groupValue: _selectedScoringMethod,
                                  onChanged: _isProcessing
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            _agreeToScoringMethod(value as String, _isCreator);
                                          }
                                        },
                                ),
                                RadioListTile(
                                  title: const Text('Request Referee'),
                                  value: 'referee_requested',
                                  groupValue: _selectedScoringMethod,
                                  onChanged: _isProcessing
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            _agreeToScoringMethod(value as String, _isCreator);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_agreeToScoring)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: cs.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'You agreed to $_selectedScoringMethod',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Dev mode approval button
                  if (_isDevMode && isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚙️ DEV MODE: Approve Challenge',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isProcessing ? null : _approveChallenge,
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Approve Challenge'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Actions
                  if (isOpen && !isCreator) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing ? null : _declineChallenge,
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isProcessing ? null : _acceptChallenge,
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isAccepted) ...[
                    if (isCreator)
                      FilledButton.icon(
                        onPressed: _isProcessing ? null : () => _startGame(challenge),
                        icon: _isProcessing ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        ) : const Icon(Icons.sports_basketball),
                        label: const Text('Start Game'),
                      )
                    else
                      Text('Waiting for creator to start game...', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
