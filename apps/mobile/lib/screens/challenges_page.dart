import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/models/challenge.dart';
import 'package:mobile/services/challenge_service.dart';
import 'package:mobile/widgets/challenge_card.dart';

final supabase = Supabase.instance.client;

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  String _selectedTab = 'available'; // 'available', 'my', 'completed'
  late Future<List<Challenge>> _challengesFuture;
  late Future<List<Challenge>> _hotChallengesFuture;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _hotChallengesFuture = ChallengeService.fetchOpenChallenges().then(
      (challenges) => challenges
          .where((c) => c.prizeAmount != null && c.prizeAmount! > 0)
          .toList()
          .take(6)
          .toList(),
    );
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
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Challenges',
          style: tt.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFFFF2D55),
                ),
                onPressed: () => context.go('/create-challenge'),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Hot Challenges section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Hot Challenges',
                style: tt.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Hot challenges carousel
            SizedBox(
              height: 280,
              child: FutureBuilder<List<Challenge>>(
                future: _hotChallengesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No hot challenges available',
                        style: tt.bodyMedium?.copyWith(
                          color: const Color(0xFFC7C7CC),
                        ),
                      ),
                    );
                  }

                  final challenges = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 12),
                        child: ChallengeCard(
                          title: challenge.challengeType,
                          subtitle: 'Prize: \$${challenge.prizeAmount ?? 0}',
                          prizeAmount: '\$${challenge.prizeAmount ?? 0}',
                          participantCount: 0,
                          isFeatured: true,
                          onTap: () => context.push(
                            '/challenges/${challenge.id}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // All challenges section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'All Challenges',
                style: tt.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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

            const SizedBox(height: 12),

            // Challenges list
            FutureBuilder<List<Challenge>>(
              future: _challengesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: const Color(0xFFC7C7CC),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading challenges',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: tt.bodySmall?.copyWith(
                              color: const Color(0xFFC7C7CC),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final challenges = snapshot.data ?? [];

                if (challenges.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sports_basketball_outlined,
                            size: 48,
                            color: const Color(0xFFC7C7CC),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No challenges available',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for new challenges',
                            style: tt.bodySmall?.copyWith(
                              color: const Color(0xFFC7C7CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildChallengeCard(
                          challenge,
                          userId,
                          cs,
                          tt,
                          context,
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String value, ColorScheme cs, TextTheme tt) {
    final isActive = _selectedTab == value;
    return FilterChip(
      selected: isActive,
      onSelected: (_) => _onTabChanged(value),
      backgroundColor:
          isActive ? const Color(0xFFFF2D55) : const Color(0xFF2C2C2E),
      selectedColor: const Color(0xFFFF2D55),
      label: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: isActive ? Colors.white : const Color(0xFFC7C7CC),
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
    final canJoin = !isCreator &&
        challenge.status == 'open' &&
        challenge.opponentId == null;

    return GestureDetector(
      onTap: () => context.push('/challenges/${challenge.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    challenge.challengeType.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(challenge.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(challenge.status),
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              challenge.description ?? challenge.challengeType,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            // Footer: Prize + Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Prize
                if (challenge.prizeAmount != null &&
                    challenge.prizeAmount! > 0) ...[
                  Row(
                    children: [
                      const Text('🏆'),
                      const SizedBox(width: 4),
                      Text(
                        '\$${challenge.prizeAmount}',
                        style: tt.labelLarge?.copyWith(
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                if (canJoin) ...[
                  FilledButton(
                    onPressed: () {
                      _acceptChallenge(challenge.id);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF32D74B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      'Join',
                      style: tt.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'open' => const Color(0xFF32D74B),
      'in_progress' => const Color(0xFFFF2D55),
      'completed' => const Color(0xFFFFD700),
      _ => const Color(0xFFC7C7CC),
    };
  }

  String _getStatusLabel(String status) {
    return switch (status) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      _ => 'Unknown',
    };
  }

  Future<void> _acceptChallenge(String challengeId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not authenticated')),
          );
        }
        return;
      }

      await supabase.from('challenges').update({'opponent_id': userId}).eq('id', challengeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge accepted!')),
        );
        setState(() {
          _loadChallenges();
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
}
