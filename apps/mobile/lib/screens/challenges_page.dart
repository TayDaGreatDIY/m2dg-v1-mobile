import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';

final supabase = Supabase.instance.client;

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  String _selectedTab = 'available'; // 'available', 'my', 'completed'
  late Future<List<Challenge>> _challengesFuture;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  void _loadChallenges() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _challengesFuture = switch (_selectedTab) {
      'available' => ChallengeService.fetchOpenChallenges(),
      'my' => ChallengeService.fetchMyChallenges(userId),
      'completed' => ChallengeService.fetchMyChallenges(userId, status: 'completed'),
      _ => ChallengeService.fetchOpenChallenges(),
    };
  }

  void _onTabChanged(String tab) {
    setState(() {
      _selectedTab = tab;
      _loadChallenges();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-challenge'),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Available', 'available', cs, tt),
                  const SizedBox(width: 8),
                  _buildTab('My Challenges', 'my', cs, tt),
                  const SizedBox(width: 8),
                  _buildTab('Completed', 'completed', cs, tt),
                ],
              ),
            ),
          ),
          // Challenges list
          Expanded(
            child: FutureBuilder<List<Challenge>>(
              future: _challengesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: cs.error),
                        const SizedBox(height: 16),
                        Text('Error loading challenges',
                            style: tt.titleMedium),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(),
                            style: tt.bodySmall,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }

                final challenges = snapshot.data ?? [];

                if (challenges.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_basketball_outlined,
                            size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No challenges available',
                            style: tt.titleMedium),
                        const SizedBox(height: 8),
                        Text('Check back later for new challenges',
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = challenges[index];
                    return _buildChallengeCard(
                      challenge,
                      userId,
                      cs,
                      tt,
                      context,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value, ColorScheme cs, TextTheme tt) {
    final isActive = _selectedTab == value;
    return FilterChip(
      selected: isActive,
      onSelected: (_) => _onTabChanged(value),
      backgroundColor: isActive ? cs.primary : cs.surfaceContainerHighest,
      selectedColor: cs.primary,
      label: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: isActive ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildChallengeCard(
    Challenge challenge,
    String? userId,
    ColorScheme cs,
    TextTheme tt,
    BuildContext context,
  ) {
    final isCreator = challenge.creatorId == userId;
    final statusColor = _getStatusColor(challenge.status, cs);
    final statusLabel = _getStatusLabel(challenge.status);
    final canJoin = !isCreator && challenge.status == 'open' && challenge.opponentId == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(challenge.challengeType.toUpperCase()),
                  backgroundColor: cs.primaryContainer,
                  labelStyle: tt.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusLabel,
                    style: tt.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Opponent info with name fetching
            FutureBuilder<String>(
              future: challenge.opponentId != null
                  ? ChallengeService.fetchOpponentName(challenge.opponentId!)
                  : Future.value('Open Challenge'),
              builder: (context, snapshot) {
                final opponentName = snapshot.data ?? 'Loading...';
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: cs.tertiary,
                          child: Text(
                            opponentName.substring(0, 1).toUpperCase(),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onTertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opponentName,
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (challenge.hasWager)
                                Text(
                                  '\$${challenge.wagerAmount?.toStringAsFixed(2) ?? '0.00'} wager',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.tertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isCreator)
                          Chip(
                            label: const Text('You'),
                            backgroundColor: cs.secondary.withValues(alpha: 0.3),
                            labelStyle: tt.labelSmall?.copyWith(
                              color: cs.onSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => context.go('/challenge/${challenge.id}'),
                            child: const Text('View Details'),
                          ),
                        ),
                        if (canJoin) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _joinChallenge(challenge.id, userId, context),
                              child: const Text('Join Challenge'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinChallenge(String challengeId, String? userId, BuildContext context) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    try {
      await ChallengeService.joinChallenge(challengeId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Successfully joined challenge!')),
        );
        context.go('/challenge/$challengeId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining challenge: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status, ColorScheme cs) {
    return switch (status) {
      'pending_approval' => cs.error,
      'open' => cs.tertiary,
      'accepted' => cs.primary,
      'in_progress' => cs.tertiary,
      'completed' => cs.secondary,
      'declined' => cs.outlineVariant,
      _ => cs.outline,
    };
  }

  String _getStatusLabel(String status) {
    return switch (status) {
      'pending_approval' => 'Pending',
      'open' => 'Open',
      'accepted' => 'Accepted',
      'in_progress' => 'Live',
      'completed' => 'Done',
      'declined' => 'Declined',
      _ => status,
    };
  }
}
