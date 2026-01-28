import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RefereeRequestsPage extends StatefulWidget {
  const RefereeRequestsPage({super.key});

  @override
  State<RefereeRequestsPage> createState() => _RefereeRequestsPageState();
}

class _RefereeRequestsPageState extends State<RefereeRequestsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _refereeRequests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefereeRequests();
  }

  Future<void> _loadRefereeRequests() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch challenges where this user is the referee (or assigned referee)
      final response = await supabase
          .from('challenges')
          .select(
              'id, creator_id, opponent_id, court_id, status, created_at, scheduled_start_time, profiles!challenges_creator_id_fkey(display_name, avatar_url), courts(name, city)')
          .eq('assigned_referee_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _refereeRequests = (response as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      print('Error loading referee requests: $e');
      setState(() {
        _error = 'Error loading requests: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRefereeRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_refereeRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No referee requests', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Players will send referee requests here',
                style: tt.bodySmall),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referee Requests'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRefereeRequests,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _refereeRequests.length,
          itemBuilder: (context, index) {
            final request = _refereeRequests[index];
            final profile = request['profiles'] as Map<String, dynamic>?;
            final court = request['courts'] as Map<String, dynamic>?;
            final status = request['status'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: profile?['avatar_url'] != null
                              ? NetworkImage(profile!['avatar_url'])
                              : null,
                          child: profile?['avatar_url'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?['display_name'] ?? 'Unknown Player',
                                style: tt.titleSmall,
                              ),
                              Text(
                                '${court?['name'] ?? 'Unknown Court'} • ${court?['city'] ?? ''}',
                                style: tt.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'waiting_for_start'
                                ? cs.primaryContainer
                                : cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: tt.labelSmall?.copyWith(
                              color: status == 'waiting_for_start'
                                  ? cs.onPrimaryContainer
                                  : cs.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (request['scheduled_start_time'] != null)
                      Text(
                        'Scheduled: ${request['scheduled_start_time']}',
                        style: tt.bodySmall,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // TODO: Accept referee request
                          },
                          child: const Text('Accept'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            // TODO: Decline referee request
                          },
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
