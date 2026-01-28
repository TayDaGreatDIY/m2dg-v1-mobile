import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RefereeCourtsPage extends StatefulWidget {
  const RefereeCourtsPage({super.key});

  @override
  State<RefereeCourtsPage> createState() => _RefereeCourtsPageState();
}

class _RefereeCourtsPageState extends State<RefereeCourtsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _activeGames = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActiveGames();
  }

  Future<void> _loadActiveGames() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch games that are looking for referees or currently active
      final response = await supabase
          .from('game_sessions')
          .select(
              'id, court_id, status, team1_score, team2_score, started_at, courts(id, name, city, location)')
          .inFilter('status', ['waiting_for_referee', 'active', 'in_progress'])
          .order('started_at', ascending: false);

      setState(() {
        _activeGames = (response as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      print('Error loading active games: $e');
      setState(() {
        _error = 'Error loading games: $e';
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
              onPressed: _loadActiveGames,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_activeGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_basketball, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No active games looking for referees',
                style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('Check back soon!', style: tt.bodySmall),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts Looking for Referees'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveGames,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _activeGames.length,
          itemBuilder: (context, index) {
            final game = _activeGames[index];
            final court = game['courts'] as Map<String, dynamic>?;
            final status = game['status'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: cs.primary,
                ),
                title: Text(court?['name'] ?? 'Unknown Court'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${court?['city'] ?? ''} • Status: $status'),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${game['team1_score'] ?? 0} - ${game['team2_score'] ?? 0}',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'waiting_for_referee'
                        ? cs.errorContainer
                        : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Accept Ref',
                    style: tt.bodySmall?.copyWith(
                      color: status == 'waiting_for_referee'
                          ? cs.onErrorContainer
                          : cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {
                  // TODO: Accept referee role for this game
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
