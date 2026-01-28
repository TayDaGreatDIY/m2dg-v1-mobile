import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/player_stats.dart';
import '../services/developer_mode_service.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<PlayerStats?> _statsFuture;
  late Future<Map<String, dynamic>?> _refereeFuture;

  bool _devModeEnabled = false;
  bool _devSimulateGps = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    // Load role FIRST, then load stats based on role
    await _loadUserRole();
    _loadProfile();
    _loadStats();
    _loadDeveloperMode();
  }

  Future<void> _loadUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await supabase
          .from('profiles')
          .select('user_role')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userRole = profile['user_role'] as String? ?? 'athlete';
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  Future<void> _loadDeveloperMode() async {
    final devMode = await DeveloperModeService.isDeveloperMode();
    final simGps = await DeveloperModeService.isGpsSimulationEnabled();
    if (mounted) {
      setState(() {
        _devModeEnabled = devMode;
        _devSimulateGps = simGps;
      });
    }
  }

  void _loadProfile() {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _profileFuture = supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single()
          .then((data) => data as Map<String, dynamic>?)
          .catchError((_) => null);
    }
  }

  void _loadStats() {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      if (_userRole == 'referee') {
        // Load referee profile instead of player stats
        _refereeFuture = supabase
            .from('referee_profiles')
            .select()
            .eq('user_id', userId)
            .maybeSingle()
            .then((data) => data as Map<String, dynamic>?)
            .catchError((_) => null);
      } else {
        // Load player stats for athletes
        _statsFuture = supabase
            .from('player_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle()
            .then((data) => data != null ? PlayerStats.fromJson(data) : null)
            .catchError((_) => null);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      // Router will automatically redirect to /sign-in due to auth state change
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loadUserRole();
      _loadProfile();
      _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          final username = profile?['username'] as String? ?? 'User';
          final displayName = profile?['display_name'] as String? ?? username;
          final userRole = _userRole ?? 'athlete';
          final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

          // Show referee stats if user is a referee
          if (userRole == 'referee') {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _refereeFuture,
              builder: (context, refSnapshot) {
                if (refSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final refProfile = refSnapshot.data;
                return _buildRefereeProfile(
                  context,
                  cs,
                  tt,
                  username,
                  displayName,
                  firstLetter,
                  refProfile,
                );
              },
            );
          }

          // Show athlete stats for regular athletes
          return FutureBuilder<PlayerStats?>(
            future: _statsFuture,
            builder: (context, statsSnapshot) {
              if (statsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = statsSnapshot.data;
              return _buildAthleteProfile(
                context,
                cs,
                tt,
                username,
                displayName,
                firstLetter,
                stats,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRefereeProfile(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    String username,
    String displayName,
    String firstLetter,
    Map<String, dynamic>? refProfile,
  ) {
    final gamesReffed = refProfile?['games_refereed_total'] ?? 0;
    final badCalls = refProfile?['bad_calls'] ?? 0;
    final rating = refProfile?['average_rating'] ?? 0.0;

    // Determine level based on games reffed
    String getLevel(int games) {
      if (games < 5) return 'Rookie';
      if (games < 20) return 'Pro';
      if (games < 50) return 'Expert';
      return 'Legend';
    }

    final level = getLevel(gamesReffed as int);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: cs.primary,
            child: Text(
              firstLetter,
              style: tt.headlineLarge?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Display Name
          Text(
            displayName,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          // Username
          Text(
            '@$username',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          // Stats section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Referee Stats',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '$gamesReffed',
                                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Games Reffed',
                                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            Container(height: 40, width: 1, color: cs.outlineVariant),
                            Column(
                              children: [
                                Text(
                                  '$badCalls',
                                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Reviews',
                                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            Container(height: 40, width: 1, color: cs.outlineVariant),
                            Column(
                              children: [
                                Text(
                                  level,
                                  style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Level',
                                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '$rating/5.0',
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('Friends & Social'),
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.mail),
                  label: const Text('Messages & Inbox'),
                  onPressed: () => context.goNamed('messagesInbox'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.errorContainer),
              onPressed: _signOut,
              child: Text('Sign Out', style: TextStyle(color: cs.onErrorContainer)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAthleteProfile(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    String username,
    String displayName,
    String firstLetter,
    PlayerStats? stats,
  ) {
    // Calculate skill level based on wins
    String getSkillLevel(int wins) {
      if (wins < 5) return 'Rookie';
      if (wins < 20) return 'Pro';
      if (wins < 50) return 'Expert';
      return 'Legend';
    }

    final skillLevel = stats != null ? getSkillLevel(stats.totalWins) : 'Rookie';

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: cs.primary,
            child: Text(
              firstLetter,
              style: tt.headlineLarge?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Display Name
          Text(
            displayName,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          // Username
          Text(
            '@$username',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          // Stats section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stats',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('${stats?.totalWins ?? 0}',
                                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Wins',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                            Container(height: 40, width: 1, color: cs.outlineVariant),
                            Column(
                              children: [
                                Text('${stats?.totalLosses ?? 0}',
                                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Losses',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                            Container(height: 40, width: 1, color: cs.outlineVariant),
                            Column(
                              children: [
                                Text(skillLevel,
                                    style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                                Text('Level',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('Friends & Social'),
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.mail),
                  label: const Text('Messages & Inbox'),
                  onPressed: () => context.goNamed('messagesInbox'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.errorContainer),
              onPressed: _signOut,
              child: Text('Sign Out', style: TextStyle(color: cs.onErrorContainer)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
