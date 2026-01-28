import 'package:flutter/material.dart';
import 'package:mobile/models/team_roster.dart';
import 'package:mobile/services/team_building_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TeamBuilderPage extends StatefulWidget {
  const TeamBuilderPage({Key? key}) : super(key: key);

  @override
  State<TeamBuilderPage> createState() => _TeamBuilderPageState();
}

class _TeamBuilderPageState extends State<TeamBuilderPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<TeamRoster> _userTeams = [];
  List<TeamRoster> _allTeams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserTeams();
    _loadAllTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserTeams() async {
    setState(() => _isLoading = true);
    final teams = await TeamBuildingService.getUserTeams();
    setState(() {
      _userTeams = teams;
      _isLoading = false;
    });
  }

  Future<void> _loadAllTeams() async {
    final teams = await TeamBuildingService.getAllPublicTeams();
    setState(() => _allTeams = teams);
  }

  Future<List<Map<String, dynamic>>> _fetchUserFriends() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Fetch accepted friendships
      final friendships = await supabase
          .from('friendships')
          .select('id, friend_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if ((friendships as List).isEmpty) return [];

      // Extract friend IDs
      final friendIds = (friendships as List)
          .cast<Map<String, dynamic>>()
          .map((f) => f['friend_id'] as String?)
          .whereType<String>()
          .toList();

      if (friendIds.isEmpty) return [];

      // Fetch friend profiles
      final profiles = await supabase
          .from('profiles')
          .select('user_id, username, display_name')
          .inFilter('user_id', friendIds);

      return (profiles as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error fetching friends: $e');
      return [];
    }
  }

  // Developer helper: Add test friends for account
  Future<void> _showAddTestFriendsDialog() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch all users except current user
      final allUsers = await supabase
          .from('profiles')
          .select('user_id, username, display_name')
          .neq('user_id', userId)
          .limit(20);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> selectedUserIds = [];

            return AlertDialog(
              title: const Text('🔧 DEV: Add Test Friends'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select users to add as friends (for testing)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: (allUsers as List).length,
                        itemBuilder: (context, index) {
                          final user = (allUsers as List)[index] as Map<String, dynamic>;
                          final userId = user['user_id'] as String?;
                          final username = user['username'] ?? 'Unknown';
                          final isSelected = selectedUserIds.contains(userId);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true && userId != null) {
                                  selectedUserIds.add(userId);
                                } else if (value == false && userId != null) {
                                  selectedUserIds.removeWhere((id) => id == userId);
                                }
                              });
                            },
                            title: Text(username),
                            subtitle: Text(user['display_name'] ?? ''),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedUserIds.isNotEmpty
                      ? () async {
                          try {
                            // Create friendships for each selected user
                            for (var friendId in selectedUserIds) {
                              await supabase.from('friendships').insert({
                                'user_id': userId,
                                'friend_id': friendId,
                                'status': 'accepted', // Auto-accept for testing
                              });
                            }

                            if (!mounted) return;
                            Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ Added ${selectedUserIds.length} test friends')),
                            );

                            // Refresh the teams/friends if needed
                            _loadUserTeams();
                            _loadAllTeams();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      : null,
                  child: const Text('Add Friends'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      print('Error: $e');
    }
  }

  void _showCreateTeamDialog() {
    final teamNameController = TextEditingController();
    String selectedGameType = '5v5';
    List<String> selectedPlayers = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Team'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Name Input
                  TextField(
                    controller: teamNameController,
                    decoration: InputDecoration(
                      labelText: 'Team Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),

                  // Game Type Selection
                  Text('Game Type:', style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('5v5'),
                          value: '5v5',
                          groupValue: selectedGameType,
                          onChanged: (val) => setDialogState(() => selectedGameType = val ?? '5v5'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('3v3'),
                          value: '3v3',
                          groupValue: selectedGameType,
                          onChanged: (val) => setDialogState(() => selectedGameType = val ?? '3v3'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Player Selection
                  Text('Select Players (${selectedPlayers.length}/${selectedGameType == '5v5' ? 5 : 3})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final players = await _showPlayerSelectionDialog(
                        selectedGameType == '5v5' ? 5 : 3,
                        selectedPlayers,
                      );
                      setDialogState(() => selectedPlayers = players);
                    },
                    icon: const Icon(Icons.person_add),
                    label: Text('Choose ${selectedGameType == "5v5" ? 5 : 3} Players'),
                  ),
                  const SizedBox(height: 8),
                  if (selectedPlayers.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: selectedPlayers.map((playerId) {
                        return Chip(
                          label: Text('Player'),
                          onDeleted: () => setDialogState(
                            () => selectedPlayers.removeWhere((p) => p == playerId),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (teamNameController.text.isNotEmpty && selectedPlayers.isNotEmpty)
                  ? () async {
                      try {
                        await TeamBuildingService.createTeam(
                          teamName: teamNameController.text,
                          gameType: selectedGameType,
                          playerIds: selectedPlayers,
                        );
                        Navigator.pop(context);
                        _loadUserTeams();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Team created!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error: $e')),
                        );
                      }
                    }
                  : null,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _showPlayerSelectionDialog(int requiredCount, List<String> currentPlayers) async {
    List<String> selected = [...currentPlayers];
    List<Map<String, dynamic>> allFriends = [];
    List<Map<String, dynamic>> filteredFriends = [];
    bool isLoadingFriends = true;
    String searchQuery = '';

    // Fetch friends on dialog load
    allFriends = await _fetchUserFriends();
    filteredFriends = allFriends;
    isLoadingFriends = false;

    return await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select $requiredCount Players'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height for better control
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header with count
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected: ${selected.length}/$requiredCount',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (selected.isNotEmpty)
                        Text(
                          '${requiredCount - selected.length} remaining',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (query) {
                    setDialogState(() {
                      searchQuery = query.toLowerCase();
                      filteredFriends = allFriends
                          .where((friend) {
                            final displayName = (friend['display_name'] as String?) ?? '';
                            final username = (friend['username'] as String?) ?? '';
                            return displayName.toLowerCase().contains(searchQuery) ||
                                username.toLowerCase().contains(searchQuery);
                          })
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Friends list - scrollable
                Expanded(
                  child: isLoadingFriends
                      ? const Center(child: CircularProgressIndicator())
                      : allFriends.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text('No friends yet', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            )
                          : filteredFriends.isEmpty
                              ? Center(
                                  child: Text('No results for "$searchQuery"', style: Theme.of(context).textTheme.bodySmall),
                                )
                              : ListView.builder(
                                  itemCount: filteredFriends.length,
                                  itemBuilder: (context, index) {
                                    final friend = filteredFriends[index];
                                    final userId = friend['user_id'] as String?;
                                    final displayName = friend['display_name'] ?? friend['username'] ?? 'Unknown';
                                    final isSelected = selected.contains(userId);
                                    final isDisabled = !isSelected && selected.length >= requiredCount;

                                    return CheckboxListTile(
                                      value: isSelected,
                                      enabled: !isDisabled,
                                      onChanged: isDisabled
                                          ? null
                                          : (bool? value) {
                                              setDialogState(() {
                                                if (value == true && userId != null) {
                                                  selected.add(userId);
                                                } else if (value == false && userId != null) {
                                                  selected.removeWhere((id) => id == userId);
                                                }
                                              });
                                            },
                                      title: Text(displayName),
                                      subtitle: Text(friend['username'] ?? ''),
                                      dense: true,
                                    );
                                  },
                                ),
                ),

                // Selected players chips
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Selected:', style: Theme.of(context).textTheme.labelSmall),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selected.map((playerId) {
                      final friend = allFriends.firstWhere(
                        (f) => f['user_id'] == playerId,
                        orElse: () => {},
                      );
                      final displayName = (friend['display_name'] ?? friend['username'] ?? 'Player') as String;
                      return Chip(
                        label: Text(displayName, style: Theme.of(context).textTheme.bodySmall),
                        onDeleted: () => setDialogState(
                          () => selected.removeWhere((id) => id == playerId),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected.length == requiredCount
                  ? () => Navigator.pop(context, selected)
                  : null,
              child: Text('Done (${selected.length}/$requiredCount)'),
            ),
          ],
        ),
      ),
    ) ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Builder'),
        elevation: 0,
        actions: [
          // Developer helper button
          Tooltip(
            message: 'Add test friends for development',
            child: IconButton(
              icon: const Icon(Icons.build),
              onPressed: _showAddTestFriendsDialog,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: 'My Teams'),
            Tab(icon: Icon(Icons.add_circle), text: 'Create'),
            Tab(icon: Icon(Icons.search), text: 'Browse'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: My Teams
          _buildMyTeamsTab(),
          // Tab 2: Create Team
          _buildCreateTeamTab(),
          // Tab 3: Browse Teams
          _buildBrowseTeamsTab(),
        ],
      ),
    );
  }

  Widget _buildMyTeamsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No teams yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Team'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userTeams.length,
      itemBuilder: (context, index) {
        final team = _userTeams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(team.teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('${team.gameType} • ${team.playerIds.length}/${team.requiredSize} players',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: team.playerIds.length / team.requiredSize,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () {
                    // TODO: Show edit dialog
                  },
                ),
                PopupMenuItem(
                  child: const Text('Delete'),
                  onTap: () => _showDeleteConfirmation(team.id),
                ),
              ],
            ),
            onTap: () => _showTeamDetails(team),
          ),
        );
      },
    );
  }

  Widget _buildCreateTeamTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_3, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Build Your Winning Team',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Organize your best players for 5v5 or 3v3 matchups',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create New Team'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseTeamsTab() {
    final otherTeams =
        _allTeams.where((team) => team.userId != supabase.auth.currentUser?.id).toList();

    if (otherTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No other teams to browse yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: otherTeams.length,
      itemBuilder: (context, index) {
        final team = otherTeams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(team.teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('${team.gameType} • ${team.playerIds.length}/${team.requiredSize} players',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: team.playerIds.length / team.requiredSize,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showChallengeTeamDialog(team),
              child: const Text('Challenge'),
            ),
            onTap: () => _showTeamDetails(team),
          ),
        );
      },
    );
  }

  void _showTeamDetails(TeamRoster team) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              team.teamName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${team.gameType} • ${team.playerIds.length}/${team.requiredSize} players'),
            const SizedBox(height: 16),
            Text('Team Members (${team.playerIds.length}/${team.requiredSize})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: team.playerIds.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Player ${index + 1}'),
                    subtitle: Text(team.playerIds[index].substring(0, 8)),
                  );
                },
              ),
            ),
            if (team.playerIds.length < team.requiredSize)
              Text(
                '${team.missingPlayers} slots available',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String teamId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await TeamBuildingService.deleteTeam(teamId);
                Navigator.pop(context);
                _loadUserTeams();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Team deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChallengeTeamDialog(TeamRoster team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Team'),
        content: Text('Challenge ${team.teamName} to a game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 Challenge sent! (TODO: implement)')),
              );
            },
            child: const Text('Challenge'),
          ),
        ],
      ),
    );
  }
}
