import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class OpponentSearchPage extends StatefulWidget {
  final String courtId;
  
  const OpponentSearchPage({required this.courtId, super.key});

  @override
  State<OpponentSearchPage> createState() => _OpponentSearchPageState();
}

class _OpponentSearchPageState extends State<OpponentSearchPage> {
  late Future<List<Map<String, dynamic>>> _playersFuture;
  late Future<List<String>> _friendsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _loadFriends();
  }

  void _loadPlayers() {
    _playersFuture = _fetchAvailablePlayers();
  }

  void _loadFriends() {
    _friendsFuture = _fetchUserFriends();
  }

  Future<List<String>> _fetchUserFriends() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('friendships')
          .select('friend_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      return List<String>.from(
        (response as List).map((item) => item['friend_id'] as String),
      );
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAvailablePlayers() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch all profiles except current user
      final response = await supabase
          .from('profiles')
          .select()
          .neq('user_id', currentUserId)
          .order('username');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching players: $e');
      throw Exception('Failed to load players: $e');
    }
  }

  Future<void> _sendFriendRequest(String recipientId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('friendships').insert({
        'user_id': userId,
        'friend_id': recipientId,
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
      setState(() => _loadFriends());
    } catch (e) {
      print('Error sending friend request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Opponent'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search players',
                hintText: 'Username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // Players list
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _friendsFuture,
              builder: (context, friendsSnapshot) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _playersFuture,
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
                            Text('Error loading players', style: tt.titleMedium),
                          ],
                        ),
                      );
                    }

                    final players = snapshot.data ?? [];
                    final friends = friendsSnapshot.data ?? [];
                    
                    final filtered = players
                        .where((p) =>
                            (p['username'] as String? ?? '')
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            (p['display_name'] as String? ?? '')
                                .toLowerCase()
                                .contains(_searchQuery))
                        .toList();

                    // Sort: friends first, then others
                    filtered.sort((a, b) {
                      final aIsFriend = friends.contains(a['id']);
                      final bIsFriend = friends.contains(b['id']);
                      return bIsFriend.toString().compareTo(aIsFriend.toString());
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No players available'
                              : 'No results found',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final player = filtered[index];
                        final playerId = player['user_id'] as String; // Use user_id, not id
                        final username = player['username'] as String? ?? 'User';
                        final displayName = player['display_name'] as String? ?? username;
                        final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';
                        final isFriend = friends.contains(playerId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(color: cs.onPrimaryContainer),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: tt.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '@$username',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      if (isFriend)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Friend',
                                            style: tt.labelSmall?.copyWith(
                                              color: cs.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Action button
                                if (isFriend)
                                  ElevatedButton(
                                    onPressed: () {
                                      context.pop({
                                        'id': playerId,
                                        'name': displayName,
                                      });
                                    },
                                    child: const Text('Select'),
                                  )
                                else
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _sendFriendRequest(playerId),
                                        icon: const Icon(Icons.person_add, size: 18),
                                        label: const Text('Add'),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          context.pop({
                                            'id': playerId,
                                            'name': displayName,
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cs.secondaryContainer,
                                        ),
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
}
