import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MessagesInboxPage extends StatefulWidget {
  const MessagesInboxPage({super.key});

  @override
  State<MessagesInboxPage> createState() => _MessagesInboxPageState();
}

class _MessagesInboxPageState extends State<MessagesInboxPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all messages where current user is sender or recipient
      final messagesData = await supabase
          .from('messages')
          .select('sender_id, recipient_id, created_at')
          .or('sender_id.eq.$userId,recipient_id.eq.$userId')
          .order('created_at', ascending: false);

      // Extract unique conversation partners
      final conversationPartners = <String>[];
      for (var msg in messagesData as List) {
        final senderId = msg['sender_id'] as String;
        final recipientId = msg['recipient_id'] as String;
        final partnerId = senderId == userId ? recipientId : senderId;
        
        if (!conversationPartners.contains(partnerId)) {
          conversationPartners.add(partnerId);
        }
      }

      // Fetch profiles for these partners
      List<Map<String, dynamic>> conversations = [];
      if (conversationPartners.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('user_id, username, display_name, skill_level')
            .inFilter('user_id', conversationPartners);

        conversations = (profiles as List)
            .cast<Map<String, dynamic>>()
            .toList();
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load conversations: $e')),
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
        title: const Text('Messages & Inbox'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 64,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: tt.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation with a friend',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showSearchDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Message a Friend'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final username = conv['username'] as String? ?? 'Unknown';
                    final displayName = conv['display_name'] as String? ?? username;
                    final userId = conv['user_id'] as String;
                    final skillLevel = conv['skill_level'] as String? ?? 'Rookie';
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
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/messages/$userId'),
                    );
                  },
                ),
      floatingActionButton: _conversations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('New Message'),
            )
          : null,
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: _UserSearchDelegate(
        onUserSelected: (userId) {
          context.push('/messages/$userId');
        },
      ),
    );
  }
}

class _UserSearchDelegate extends SearchDelegate<String?> {
  final Function(String) onUserSelected;

  _UserSearchDelegate({required this.onUserSelected});

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
            final userId = user['user_id'] as String;
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
              trailing: const Icon(Icons.message_outlined),
              onTap: () {
                onUserSelected(userId);
                close(context, userId);
              },
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
