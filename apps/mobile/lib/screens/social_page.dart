import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

final supabase = Supabase.instance.client;

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load accepted friends (simple select without relationship join)
      final friendsData = await supabase
          .from('friendships')
          .select('id, friend_id, status, created_at')
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      // Load pending requests (received) - simple select without relationship join
      final requestsData = await supabase
          .from('friendships')
          .select('id, user_id, status, created_at')
          .eq('friend_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      // Fetch profiles for friends
      List<Map<String, dynamic>> friendsList = [];
      {
        final friendIds = (friendsData as List)
            .cast<Map<String, dynamic>>()
            .map((f) => f['friend_id'] as String?)
            .whereType<String>()
            .toList();
        
        if (friendIds.isNotEmpty) {
          final profiles = await supabase
              .from('profiles')
              .select('id, user_id, username, display_name, skill_level')
              .inFilter('user_id', friendIds);
          
          // Merge friendship and profile data
          for (var friendship in friendsData as List) {
            final profile = (profiles as List)
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (p) => p['user_id'] == friendship['friend_id'],
                  orElse: () => {},
                );
            if (profile.isNotEmpty) {
              friendsList.add({...friendship, 'friend': profile});
            }
          }
        }
      }

      // Fetch profiles for pending requests
      List<Map<String, dynamic>> requestsList = [];
      {
        final requesterIds = (requestsData as List)
            .cast<Map<String, dynamic>>()
            .map((f) => f['user_id'] as String?)
            .whereType<String>()
            .toList();
        
        if (requesterIds.isNotEmpty) {
          final profiles = await supabase
              .from('profiles')
              .select('id, user_id, username, display_name, skill_level')
              .inFilter('user_id', requesterIds);
          
          // Merge friendship and profile data
          for (var friendship in requestsData as List) {
            final profile = (profiles as List)
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (p) => p['user_id'] == friendship['user_id'],
                  orElse: () => {},
                );
            if (profile.isNotEmpty) {
              requestsList.add({...friendship, 'requester': profile});
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _friends = friendsList;
          _pendingRequests = requestsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String friendshipId, String requesterUserId) async {
    try {
      await supabase
          .from('friendships')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', friendshipId);

      // Note: No reciprocal friendship needed - queries handle both directions
      // Refresh data after accepting
      await Future.delayed(const Duration(milliseconds: 500));
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept request: $e')),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(String friendshipId) async {
    try {
      await supabase
          .from('friendships')
          .update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', friendshipId);

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject request: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Delete both friendship records
      await supabase
          .from('friendships')
          .delete()
          .or('user_id.eq.$userId,friend_id.eq.$userId')
          .or('user_id.eq.$friendId,friend_id.eq.$friendId');

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove friend: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers() async {
    final result = await showSearch(
      context: context,
      delegate: UserSearchDelegate(),
    );

    if (result != null && mounted) {
      _sendFriendRequest(result);
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('friendships').insert({
        'user_id': userId,
        'friend_id': friendId,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Friends (${_friends.length})'),
            Tab(text: 'Requests (${_pendingRequests.length})'),
            const Tab(text: 'Find'),
            const Tab(text: 'Teams'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Friends List
                _friends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No friends yet', style: tt.titleMedium),
                            const SizedBox(height: 8),
                            Text('Search for users to add friends', style: tt.bodySmall),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            final friendship = _friends[index];
                            final friend = friendship['friend'] as Map<String, dynamic>;
                            final username = friend['username'] as String? ?? 'Unknown';
                            final displayName = friend['display_name'] as String? ?? username;
                            final skillLevel = friend['skill_level'] as String? ?? 'Rookie';
                            final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary,
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Text('@$username · $skillLevel'),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'message',
                                    child: Row(
                                      children: [
                                        Icon(Icons.message_outlined),
                                        SizedBox(width: 8),
                                        Text('Message'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'challenge',
                                    child: Row(
                                      children: [
                                        Icon(Icons.sports_basketball_outlined),
                                        SizedBox(width: 8),
                                        Text('Challenge'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_outlined, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove Friend', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    _removeFriend(friend['id'] as String);
                                  } else if (value == 'message') {
                                    context.push('/messages/${friend['id']}');
                                  } else if (value == 'challenge') {
                                    // TODO: Implement challenge flow
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Challenge feature coming soon')),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                // Friend Requests
                _pendingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline, size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No pending requests', style: tt.titleMedium),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          itemCount: _pendingRequests.length,
                          itemBuilder: (context, index) {
                            final request = _pendingRequests[index];
                            final requester = request['requester'] as Map<String, dynamic>;
                            final username = requester['username'] as String? ?? 'Unknown';
                            final displayName = requester['display_name'] as String? ?? username;
                            final skillLevel = requester['skill_level'] as String? ?? 'Rookie';
                            final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary,
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Text('@$username · $skillLevel'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _acceptFriendRequest(
                                      request['id'] as String,
                                      requester['user_id'] as String,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _rejectFriendRequest(request['id'] as String),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                // Find Users
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 64, color: cs.primary),
                        const SizedBox(height: 24),
                        Text(
                          'Find Friends',
                          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for other players to add as friends',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _searchUsers,
                          icon: const Icon(Icons.search),
                          label: const Text('Search Users'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Teams Tab
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_3, size: 64, color: cs.primary),
                        const SizedBox(height: 24),
                        Text(
                          'Team Building',
                          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Build your Starting 5 or 3v3 lineup and challenge friends',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () => context.go('/team-builder'),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Go to Team Builder'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class UserSearchDelegate extends SearchDelegate<String?> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Search for users by username'));
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final username = user['username'] as String? ?? 'Unknown';
            final displayName = user['display_name'] as String? ?? username;
            final skillLevel = user['skill_level'] as String? ?? 'Rookie';
            final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary,
                child: Text(
                  firstLetter,
                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(displayName),
              subtitle: Text('@$username · $skillLevel'),
              trailing: const Icon(Icons.person_add_outlined),
              onTap: () => close(context, user['user_id'] as String),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.isEmpty) return [];

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final results = await supabase
          .from('profiles')
          .select()
          .neq('user_id', userId) // Exclude current user
          .ilike('username', '%$query%')
          .limit(20);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      return [];
    }
  }
}
