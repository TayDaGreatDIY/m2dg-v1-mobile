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

  bool _devModeEnabled = false;
  bool _devSimulateGps = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
    _loadDeveloperMode();
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
      _statsFuture = supabase
          .from('player_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .then((data) => data != null ? PlayerStats.fromJson(data) : null)
          .catchError((_) => null);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
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
          final skillLevel = profile?['skill_level'] as String? ?? 'Rookie';
          final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

          return FutureBuilder<PlayerStats?>(
            future: _statsFuture,
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data;
              
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          Text('${stats?.totalWins ?? 0}',
                                              style: tt.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                          Text('Wins',
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant)),
                                        ],
                                      ),
                                      Container(
                                        height: 40,
                                        width: 1,
                                        color: cs.outlineVariant,
                                      ),
                                      Column(
                                        children: [
                                          Text('${stats?.totalLosses ?? 0}',
                                              style: tt.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                          Text('Losses',
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant)),
                                        ],
                                      ),
                                      Container(
                                        height: 40,
                                        width: 1,
                                        color: cs.outlineVariant,
                                      ),
                                      Column(
                                        children: [
                                          Text(skillLevel,
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.bold)),
                                          Text('Level',
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (stats != null) ...[
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            Text('${stats.winRate.toStringAsFixed(1)}%',
                                                style: tt.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: cs.primary)),
                                            Text('Win Rate',
                                                style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant)),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text('${stats.totalGames}',
                                                style: tt.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold)),
                                            Text('Games',
                                                style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant)),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text('${stats.pointDifferential >= 0 ? '+' : ''}${stats.pointDifferential}',
                                                style: tt.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: stats.pointDifferential >= 0 
                                                        ? Colors.green 
                                                        : Colors.red)),
                                            Text('Point Diff',
                                                style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => context.push('/social'),
                            icon: const Icon(Icons.people),
                            label: const Text('Friends & Social'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => context.push('/messages-inbox'),
                            icon: const Icon(Icons.mail_outline),
                            label: const Text('Messages & Inbox'),
                          ),
                          const SizedBox(height: 24),
                          // Developer Settings Section
                          if (_devModeEnabled)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.tertiary),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '🔧 Developer Mode',
                                        style: tt.titleSmall?.copyWith(
                                          color: cs.onTertiaryContainer,
                                        ),
                                      ),
                                      Switch(
                                        value: _devSimulateGps,
                                        onChanged: (v) async {
                                          await DeveloperModeService
                                              .setSimulateGps(v);
                                          if (mounted) {
                                            setState(
                                                () => _devSimulateGps = v);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  v
                                                      ? '✅ GPS Simulation Enabled'
                                                      : '❌ GPS Simulation Disabled',
                                                ),
                                                duration: const Duration(
                                                    seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Simulate GPS Location\nYou\'ll be treated as close to courts for testing check-ins',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onTertiaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When enabled, check-ins will succeed without GPS validation',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onTertiaryContainer
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          // Developer Mode Toggle
                          OutlinedButton.icon(
                            onPressed: () async {
                              final newMode = await DeveloperModeService
                                  .toggleDeveloperMode();
                              if (mounted) {
                                setState(() => _devModeEnabled = newMode);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      newMode
                                          ? '✅ Developer Mode Enabled'
                                          : '❌ Developer Mode Disabled',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.bug_report),
                            label: Text(
                              _devModeEnabled
                                  ? 'Developer Mode (ON)'
                                  : 'Developer Mode (OFF)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _signOut,
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
