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

      // Fetch challenges where this user is the referee
      final response = await supabase
          .from('challenges')
          .select('*')
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
            final status = request['status'] as String? ?? 'pending';
            final scheduledTime = request['scheduled_start_time'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Challenge Request',
                                style: tt.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              if (scheduledTime != null)
                                Text(
                                  'Scheduled: $scheduledTime',
                                  style: tt.bodySmall,
                                ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'pending'
                                      ? cs.primaryContainer
                                      : cs.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.replaceAll('_', ' ').toUpperCase(),
                                  style: tt.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Decline request
                              print('Decline request: ${request['id']}');
                            },
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              // TODO: Accept request
                              print('Accept request: ${request['id']}');
                            },
                            child: const Text('Accept'),
                          ),
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
