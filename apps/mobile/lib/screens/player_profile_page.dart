import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PlayerProfilePage extends StatefulWidget {
  final String userId;

  const PlayerProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _loading = true;
  String? _error;
  
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _court;
  bool _isFriend = false;
  bool _checkingFriendship = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkFriendshipStatus();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Load profile
      final profileData = await supabase
          .from('profiles')
          .select('*')
          .eq('user_id', widget.userId)
          .single();

      // Load player stats
      final statsData = await supabase
          .from('player_stats')
          .select('*')
          .eq('user_id', widget.userId)
          .single();

      // Load home court if exists
      Map<String, dynamic>? courtData;
      if (profileData['favorite_court_id'] != null) {
        final court = await supabase
            .from('courts')
            .select('id, name, city, state')
            .eq('id', profileData['favorite_court_id'])
            .maybeSingle();
        courtData = court;
      }

      setState(() {
        _profile = profileData;
        _stats = statsData;
        _court = courtData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.id == widget.userId) {
        setState(() => _isFriend = false);
        return;
      }

      final friendship = await supabase
          .from('friendships')
          .select('status')
          .eq('user_id', currentUser.id)
          .eq('friend_id', widget.userId)
          .maybeSingle();

      setState(() => _isFriend = friendship != null && friendship['status'] == 'accepted');
    } catch (e) {
      print('Error checking friendship: $e');
    }
  }

  Future<void> _addFriend() async {
    try {
      setState(() => _checkingFriendship = true);
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase.from('friendships').insert({
        'user_id': currentUser.id,
        'friend_id': widget.userId,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
      setState(() => _checkingFriendship = false);
    } catch (e) {
      setState(() => _checkingFriendship = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatWinRate() {
    if (_stats == null) return '0%';
    final total = (_stats!['total_games'] as int?) ?? 0;
    if (total == 0) return '0%';
    final wins = (_stats!['total_wins'] as int?) ?? 0;
    final rate = (wins / total * 100).toStringAsFixed(1);
    return '$rate%';
  }

  String _formatPointDiff() {
    if (_stats == null) return '0';
    final scored = (_stats!['total_points_scored'] as int?) ?? 0;
    final against = (_stats!['total_points_against'] as int?) ?? 0;
    final diff = scored - against;
    return diff > 0 ? '+$diff' : '$diff';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(_error ?? 'Profile not found'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = _profile!['display_name'] as String? ?? 'Unknown Player';
    final username = _profile!['username'] as String? ?? '';
    final bio = _profile!['bio'] as String? ?? '';
    final position = _profile!['preferred_position'] as String? ?? '';
    final skillLevel = _profile!['skill_level'] as String? ?? 'Beginner';
    final avatarUrl = _profile!['avatar_url'] as String?;

    final totalGames = (_stats!['total_games'] as int?) ?? 0;
    final totalWins = (_stats!['total_wins'] as int?) ?? 0;
    final totalLosses = (_stats!['total_losses'] as int?) ?? 0;
    final pointsScored = (_stats!['total_points_scored'] as int?) ?? 0;
    final pointsAgainst = (_stats!['total_points_against'] as int?) ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Player Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              color: cs.surfaceContainerHigh,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  avatarUrl != null
                      ? CircleAvatar(
                          radius: 60,
                          backgroundImage: NetworkImage(avatarUrl),
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: tt.headlineLarge?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  
                  // Name & Username
                  Text(
                    displayName,
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '@$username',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  // Skill Level & Position
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        label: Text(skillLevel),
                        avatar: const Icon(Icons.star, size: 18),
                        backgroundColor: cs.tertiaryContainer,
                        labelStyle: TextStyle(color: cs.onTertiaryContainer),
                      ),
                      if (position.isNotEmpty)
                        Chip(
                          label: Text(position),
                          avatar: const Icon(Icons.sports_basketball, size: 18),
                          backgroundColor: cs.secondaryContainer,
                          labelStyle: TextStyle(color: cs.onSecondaryContainer),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Follow/Friend Button (if not current user)
                  if (supabase.auth.currentUser?.id != widget.userId)
                    SizedBox(
                      width: double.infinity,
                      child: _isFriend
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.done),
                              label: const Text('Friends'),
                              onPressed: null,
                            )
                          : FilledButton.icon(
                              icon: const Icon(Icons.person_add),
                              label: const Text('Follow'),
                              onPressed: _checkingFriendship ? null : _addFriend,
                            ),
                    ),
                ],
              ),
            ),

            // Bio Section
            if (bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: tt.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Stats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistics',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _StatCard(
                        label: 'Total Games',
                        value: '$totalGames',
                        icon: Icons.sports_basketball_outlined,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        label: 'Win Rate',
                        value: _formatWinRate(),
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                      _StatCard(
                        label: 'Wins',
                        value: '$totalWins',
                        icon: Icons.check_circle_outlined,
                        color: Colors.green,
                      ),
                      _StatCard(
                        label: 'Losses',
                        value: '$totalLosses',
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'Points For',
                        value: '$pointsScored',
                        icon: Icons.arrow_upward,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        label: 'Point Diff',
                        value: _formatPointDiff(),
                        icon: Icons.difference,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Home Court Section
            if (_court != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home Court',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _court!['name'] ?? 'Unknown',
                                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${_court!['city']}, ${_court!['state']}',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
