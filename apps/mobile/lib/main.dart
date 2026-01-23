import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  Env.validate();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const MyApp());
}

/* =========================
   ROUTER + APP SHELL
   ========================= */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/courts',
      routes: [
        GoRoute(path: '/', redirect: (_, __) => '/courts'),
        GoRoute(
          path: '/courts',
          builder: (context, state) => const CourtsPage(),
        ),
        GoRoute(
          path: '/courts/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final extra = state.extra;
            final court = extra is Map<String, dynamic> ? extra : null;
            return CourtDetailsPage(courtId: id, court: court);
          },
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'M2DG v1',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}

/* =========================
   B) COURTS LIST: SEARCH / FILTER / SORT
   ========================= */

enum CourtsFilter { all, active, inactive }

enum CourtsSort { newest, nameAz }

class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _courts = const [];

  // Step B state
  final TextEditingController _searchCtrl = TextEditingController();
  CourtsFilter _filter = CourtsFilter.all;
  CourtsSort _sort = CourtsSort.newest;

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _client.from('courts').select(
            'id,name,address,city,state,country,lat,lng,is_active,created_at,radius_meters',
          );

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _courts = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleCourts {
    final q = _searchCtrl.text.trim().toLowerCase();

    bool matchesQuery(Map<String, dynamic> c) {
      if (q.isEmpty) return true;
      final haystack = [
        (c['name'] ?? ''),
        (c['address'] ?? ''),
        (c['city'] ?? ''),
        (c['state'] ?? ''),
        (c['country'] ?? ''),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }

    bool matchesFilter(Map<String, dynamic> c) {
      final isActive = c['is_active'] == true;
      return switch (_filter) {
        CourtsFilter.all => true,
        CourtsFilter.active => isActive,
        CourtsFilter.inactive => !isActive,
      };
    }

    final filtered =
        _courts.where(matchesQuery).where(matchesFilter).map((e) => e).toList();

    int compareByNewest(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ad = _parseDate(a['created_at']);
      final bd = _parseDate(b['created_at']);
      // newest first
      return bd.compareTo(ad);
    }

    int compareByName(Map<String, dynamic> a, Map<String, dynamic> b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    }

    switch (_sort) {
      case CourtsSort.newest:
        filtered.sort(compareByNewest);
        break;
      case CourtsSort.nameAz:
        filtered.sort(compareByName);
        break;
    }

    return filtered;
  }

  DateTime _parseDate(dynamic value) {
    try {
      if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch ((_loading, _error)) {
      (true, _) => const Center(child: CircularProgressIndicator()),
      (false, String err) => _ErrorState(
          title: 'Could not load courts',
          message: err,
          onRetry: _loadCourts,
        ),
      (false, null) => _visibleCourts.isEmpty
          ? _EmptyState(
              onRefresh: _loadCourts,
              subtitle: _searchCtrl.text.trim().isEmpty
                  ? 'Insert a court row in Supabase, then refresh.'
                  : 'No results for "${_searchCtrl.text.trim()}". Try a different search.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _visibleCourts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                // index 0 = controls header
                if (index == 0) return _ControlsHeader();
                final c = _visibleCourts[index - 1];
                return _CourtRow(court: c);
              },
            ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCourts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _ControlsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search courts (name, city, address...)',
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () => _searchCtrl.clear(),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter + Sort row
        Row(
          children: [
            Expanded(
              child: SegmentedButton<CourtsFilter>(
                segments: const [
                  ButtonSegment(value: CourtsFilter.all, label: Text('All')),
                  ButtonSegment(
                      value: CourtsFilter.active, label: Text('Active')),
                  ButtonSegment(
                      value: CourtsFilter.inactive, label: Text('Inactive')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<CourtsSort>(
              tooltip: 'Sort',
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: CourtsSort.newest,
                  child: Text('Sort: Newest'),
                ),
                PopupMenuItem(
                  value: CourtsSort.nameAz,
                  child: Text('Sort: Name A–Z'),
                ),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(_sort == CourtsSort.newest ? 'Newest' : 'Name A–Z'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CourtRow extends StatelessWidget {
  final Map<String, dynamic> court;

  const _CourtRow({required this.court});

  @override
  Widget build(BuildContext context) {
    final id = (court['id'] ?? '').toString();
    final name = (court['name'] ?? 'Unnamed court').toString();

    final address = (court['address'] ?? '').toString();
    final city = (court['city'] ?? '').toString();
    final state = (court['state'] ?? '').toString();
    final country = (court['country'] ?? '').toString();

    final radius = court['radius_meters']; // can be null
    final isActive = court['is_active'] == true;

    final locationLine = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');

    final subtitle = [
      if (address.isNotEmpty) address,
      if (locationLine.isNotEmpty) locationLine,
      if (radius != null) 'Radius: ${radius.toString()}m',
    ].join(' • ');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        // Step A: tap -> details
        context.go('/courts/$id', extra: court);
      },
      child: Card(
        elevation: 1,
        child: ListTile(
          leading: Icon(
            Icons.sports_basketball,
            color: isActive ? Colors.green : Colors.grey,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
          trailing: isActive
              ? const Chip(label: Text('Active'))
              : const Chip(label: Text('Inactive')),
        ),
      ),
    );
  }
}

/* =========================
   A) COURT DETAILS
   ========================= */

class CourtDetailsPage extends StatefulWidget {
  final String courtId;
  final Map<String, dynamic>? court;

  const CourtDetailsPage({
    super.key,
    required this.courtId,
    this.court,
  });

  @override
  State<CourtDetailsPage> createState() => _CourtDetailsPageState();
}

class _CourtDetailsPageState extends State<CourtDetailsPage> {
  final _client = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _court;

  @override
  void initState() {
    super.initState();
    _court = widget.court;
    if (_court == null) {
      _fetchCourt();
    }
  }

  Future<void> _fetchCourt() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _client
          .from('courts')
          .select(
            'id,name,address,city,state,country,lat,lng,is_active,created_at,radius_meters',
          )
          .eq('id', widget.courtId)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _error = 'Court not found.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _court = Map<String, dynamic>.from(res as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _court;

    if (_loading && c == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Court Details')),
        body: _ErrorState(
          title: 'Could not load court',
          message: _error!,
          onRetry: _fetchCourt,
        ),
      );
    }

    final name = (c?['name'] ?? 'Unnamed court').toString();
    final address = (c?['address'] ?? '').toString();
    final city = (c?['city'] ?? '').toString();
    final state = (c?['state'] ?? '').toString();
    final country = (c?['country'] ?? '').toString();
    final lat = c?['lat'];
    final lng = c?['lng'];
    final radius = c?['radius_meters'];
    final isActive = c?['is_active'] == true;

    final locationLine = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Court Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchCourt,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_basketball,
                color: isActive ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              isActive
                  ? const Chip(label: Text('Active'))
                  : const Chip(label: Text('Inactive')),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Address', address.isEmpty ? '—' : address),
                  _kv('Location', locationLine.isEmpty ? '—' : locationLine),
                  _kv('Latitude', lat?.toString() ?? '—'),
                  _kv('Longitude', lng?.toString() ?? '—'),
                  _kv('Radius (meters)', radius?.toString() ?? '—'),
                  _kv('Court ID', widget.courtId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Next upgrades will go here (Check-in, map, queue, etc.).',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

/* =========================
   SMALL UI HELPERS
   ========================= */

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String subtitle;

  const _EmptyState({
    required this.onRefresh,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No courts found.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
