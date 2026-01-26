import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

final supabase = Supabase.instance.client;

class CourtAdminPage extends StatefulWidget {
  final String courtId;

  const CourtAdminPage({
    required this.courtId,
    super.key,
  });

  @override
  State<CourtAdminPage> createState() => _CourtAdminPageState();
}

class _CourtAdminPageState extends State<CourtAdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _court;
  List<Map<String, dynamic>> _checkIns = [];
  List<Map<String, dynamic>> _queues = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if user is admin for this court
      final adminData = await supabase
          .from('court_admins')
          .select()
          .eq('court_id', widget.courtId)
          .eq('user_id', userId)
          .maybeSingle();

      if (adminData == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not an admin for this court')),
          );
        }
        return;
      }

      setState(() => _isAdmin = true);
      _loadData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify admin status: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (!_isAdmin) return;

    setState(() => _isLoading = true);
    try {
      // Load court details
      final courtData = await supabase
          .from('courts')
          .select()
          .eq('id', widget.courtId)
          .single();

      // Load check-ins
      final checkInsData = await supabase
          .from('court_check_ins')
          .select('*, user:profiles!court_check_ins_user_id_fkey(id, username, display_name)')
          .eq('court_id', widget.courtId)
          .order('created_at', ascending: false);

      // Load queues
      final queuesData = await supabase
          .from('court_queues')
          .select('*, user:profiles!court_queues_user_id_fkey(id, username, display_name)')
          .eq('court_id', widget.courtId)
          .order('joined_at', ascending: true);

      if (mounted) {
        setState(() {
          _court = courtData;
          _checkIns = List<Map<String, dynamic>>.from(checkInsData);
          _queues = List<Map<String, dynamic>>.from(queuesData);
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

  Future<void> _removeCheckIn(String checkInId) async {
    try {
      await supabase.from('court_check_ins').delete().eq('id', checkInId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove check-in: $e')),
        );
      }
    }
  }

  Future<void> _removeFromQueue(String queueId) async {
    try {
      await supabase.from('court_queues').delete().eq('id', queueId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player removed from queue')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove from queue: $e')),
        );
      }
    }
  }

  Future<void> _clearAllQueues() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Queues?'),
        content: const Text('This will remove all players from all queues at this court.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('court_queues').delete().eq('court_id', widget.courtId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All queues cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear queues: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Court Admin')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final courtName = _court?['name'] as String? ?? 'Unknown Court';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Court Admin', style: TextStyle(fontSize: 16)),
            Text(courtName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Check-ins (${_checkIns.length})'),
            Tab(text: 'Queues (${_queues.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Check-ins Tab
          _checkIns.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined, size: 64, color: cs.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No active check-ins', style: tt.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _checkIns.length,
                  itemBuilder: (context, index) {
                    final checkIn = _checkIns[index];
                    final user = checkIn['user'] as Map<String, dynamic>?;
                    final username = user?['username'] as String? ?? 'Unknown';
                    final displayName = user?['display_name'] as String? ?? username;
                    final createdAt = DateTime.parse(checkIn['created_at'] as String);
                    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary,
                          child: Text(
                            firstLetter,
                            style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text('@$username · ${timeago.format(createdAt)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeCheckIn(checkIn['id'] as String),
                        ),
                      ),
                    );
                  },
                ),
          // Queues Tab
          Column(
            children: [
              if (_queues.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.tonal(
                    onPressed: _clearAllQueues,
                    child: const Text('Clear All Queues'),
                  ),
                ),
              Expanded(
                child: _queues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.queue_outlined, size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No players in queue', style: tt.titleMedium),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _queues.length,
                        itemBuilder: (context, index) {
                          final queue = _queues[index];
                          final user = queue['user'] as Map<String, dynamic>?;
                          final username = user?['username'] as String? ?? 'Unknown';
                          final displayName = user?['display_name'] as String? ?? username;
                          final joinedAt = DateTime.parse(queue['joined_at'] as String);
                          final challengeType = queue['challenge_type'] as String;
                          final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary,
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@$username'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          challengeType,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeago.format(joinedAt),
                                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeFromQueue(queue['id'] as String),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
