import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

enum LeaderboardSort {
  winRate,
  totalWins,
  totalGames,
  pointsDiff,
}

extension LeaderboardSortLabel on LeaderboardSort {
  String get label {
    switch (this) {
      case LeaderboardSort.winRate:
        return 'Win Rate ↓';
      case LeaderboardSort.totalWins:
        return 'Total Wins ↓';
      case LeaderboardSort.totalGames:
        return 'Total Games ↓';
      case LeaderboardSort.pointsDiff:
        return 'Point Diff ↓';
    }
  }
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _loading = true;
  String? _error;
  
  List<Map<String, dynamic>> _allPlayers = [];
  List<Map<String, dynamic>> _filteredPlayers = [];
  
  LeaderboardSort _sort = LeaderboardSort.winRate;
  String? _skillFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> skillLevels = ['All', 'Beginner', 'Intermediate', 'Advanced', 'Pro'];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _searchCtrl.addListener(_filterPlayers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch all player stats
      final statsResponse = await supabase
          .from('player_stats')
          .select('*')
          .order('total_wins', ascending: false);

      // Fetch all profiles
      final profilesResponse = await supabase
          .from('profiles')
          .select('*');

      // Convert to proper maps
      final statsList = (statsResponse as List).map((row) {
        return Map<String, dynamic>.from(row as Map);
      }).toList();

      final profilesMap = {
        for (var p in (profilesResponse as List))
          (p['user_id'] as String): Map<String, dynamic>.from(p as Map)
      };

      // Merge stats with profiles
      final players = statsList.map((stat) {
        final userId = stat['user_id'] as String;
        final profile = profilesMap[userId];
        return {
          ...stat,
          'profile': profile,
        };
      }).toList();

      setState(() {
        _allPlayers = players;
        _skillFilter = 'All';
        _loading = false;
      });

      _filterPlayers();
    } catch (e) {
      setState(() {
        _error = 'Failed to load leaderboard: $e';
        _loading = false;
      });
    }
  }

  void _filterPlayers() {
    var filtered = List<Map<String, dynamic>>.from(_allPlayers);

    // Filter by skill level (case-insensitive comparison)
    if (_skillFilter != null && _skillFilter != 'All') {
      filtered = filtered.where((p) {
        final profile = p['profile'] as Map?;
        final skillFromProfile = (profile?['skill_level'] as String? ?? '').toLowerCase();
        final skillFilter = (_skillFilter ?? '').toLowerCase();
        return skillFromProfile == skillFilter;
      }).toList();
    }

    // Filter by search
    final query = _searchCtrl.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final profile = p['profile'] as Map?;
        final username = (profile?['username'] as String? ?? '').toLowerCase();
        final displayName = (profile?['display_name'] as String? ?? '').toLowerCase();
        return username.contains(query) || displayName.contains(query);
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      switch (_sort) {
        case LeaderboardSort.winRate:
          final aTotal = (a['total_games'] as int?) ?? 0;
          final bTotal = (b['total_games'] as int?) ?? 0;
          if (aTotal == 0 || bTotal == 0) return bTotal.compareTo(aTotal);
          final aWins = (a['total_wins'] as int?) ?? 0;
          final bWins = (b['total_wins'] as int?) ?? 0;
          final aRate = aWins / aTotal;
          final bRate = bWins / bTotal;
          return bRate.compareTo(aRate);

        case LeaderboardSort.totalWins:
          return (b['total_wins'] as int? ?? 0).compareTo(a['total_wins'] as int? ?? 0);

        case LeaderboardSort.totalGames:
          return (b['total_games'] as int? ?? 0).compareTo(a['total_games'] as int? ?? 0);

        case LeaderboardSort.pointsDiff:
          final aScored = (a['total_points_scored'] as int? ?? 0);
          final aAgainst = (a['total_points_against'] as int? ?? 0);
          final aDiff = aScored - aAgainst;

          final bScored = (b['total_points_scored'] as int? ?? 0);
          final bAgainst = (b['total_points_against'] as int? ?? 0);
          final bDiff = bScored - bAgainst;

          return bDiff.compareTo(aDiff);
      }
    });

    setState(() => _filteredPlayers = filtered);
  }

  String _getWinRate(Map<String, dynamic> player) {
    final total = (player['total_games'] as int?) ?? 0;
    if (total == 0) return '-';
    final wins = (player['total_wins'] as int?) ?? 0;
    final rate = (wins / total * 100).toStringAsFixed(1);
    return '$rate%';
  }

  String _getPointDiff(Map<String, dynamic> player) {
    final scored = (player['total_points_scored'] as int?) ?? 0;
    final against = (player['total_points_against'] as int?) ?? 0;
    final diff = scored - against;
    return diff > 0 ? '+$diff' : '$diff';
  }

  void _goToPlayerProfile(String userId) {
    context.push('/player/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLeaderboard,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: _filteredPlayers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: cs.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'No players found',
                                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  // Search bar
                                  TextField(
                                    controller: _searchCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Search player...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Filters and sort row
                                  Row(
                                    children: [
                                      // Skill filter dropdown
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _skillFilter ?? 'All',
                                          items: skillLevels.map((skill) {
                                            return DropdownMenuItem(value: skill, child: Text(skill));
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() => _skillFilter = val);
                                            _filterPlayers();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Sort dropdown
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButton<LeaderboardSort>(
                                          isExpanded: true,
                                          value: _sort,
                                          items: LeaderboardSort.values.map((sort) {
                                            return DropdownMenuItem(value: sort, child: Text(sort.label));
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _sort = val);
                                              _filterPlayers();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Player list
                            Expanded(
                              child: ListView.builder(
                                itemCount: _filteredPlayers.length,
                                itemBuilder: (ctx, idx) {
                                  final player = _filteredPlayers[idx];
                                  final profile = player['profile'] as Map?;
                                  final rank = idx + 1;
                                  final wins = (player['total_wins'] as int?) ?? 0;
                                  final losses = (player['total_losses'] as int?) ?? 0;
                                  final avatarUrl = profile?['avatar_url'] as String?;
                                  final username = profile?['username'] as String? ?? 'Unknown';
                                  final displayName = profile?['display_name'] as String? ?? '';
                                  final skillLevel = profile?['skill_level'] as String? ?? '';
                                  final userId = player['user_id'] as String? ?? '';

                                  // Rank badge color
                                  Color rankBgColor;
                                  Color rankTextColor;
                                  if (rank == 1) {
                                    rankBgColor = const Color(0xFFFFD700); // Gold
                                    rankTextColor = Colors.black;
                                  } else if (rank == 2) {
                                    rankBgColor = const Color(0xFFC0C0C0); // Silver
                                    rankTextColor = Colors.black;
                                  } else if (rank == 3) {
                                    rankBgColor = const Color(0xFFCD7F32); // Bronze
                                    rankTextColor = Colors.white;
                                  } else {
                                    rankBgColor = cs.surfaceContainerHighest;
                                    rankTextColor = cs.onSurface;
                                  }

                                  return GestureDetector(
                                    onTap: () => _goToPlayerProfile(userId),
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Rank badge
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: rankBgColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '#$rank',
                                                  style: tt.labelLarge?.copyWith(color: rankTextColor),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Avatar + name
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: cs.primary,
                                                image: avatarUrl != null
                                                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                                                    : null,
                                              ),
                                              child: avatarUrl == null
                                                  ? Center(
                                                      child: Text(
                                                        (displayName.isEmpty ? username : displayName).substring(0, 1).toUpperCase(),
                                                        style: tt.labelLarge?.copyWith(color: Colors.white),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            // Player info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayName.isNotEmpty ? displayName : username,
                                                    style: tt.titleSmall,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (displayName.isNotEmpty)
                                                    Text(
                                                      '@$username',
                                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  if (skillLevel.isNotEmpty)
                                                    Text(
                                                      skillLevel,
                                                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Stats
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$wins-$losses',
                                                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  '${_getWinRate(player)} WR',
                                                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                                ),
                                                Text(
                                                  '${_getPointDiff(player)} PD',
                                                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
    );
  }
}
