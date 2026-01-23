import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads .env (for web you must also list it under flutter/assets in pubspec.yaml)
  await dotenv.load(fileName: ".env");
  Env.validate();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/courts',
    routes: <RouteBase>[
      GoRoute(
        path: '/courts',
        builder: (context, state) => const CourtsPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CourtDetailsPage(courtId: id);
            },
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'M2DG v1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _activeOnly = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _courts = const [];

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCourts();

    // Debounced search
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _loadCourts();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = _searchCtrl.text.trim();

      // Build filters FIRST, then apply transforms (like order) LAST.
      // In supabase_dart v2, calling `order()` returns a TransformBuilder,
      // and you can't call `.eq()` / `.or()` after that.
      var query = _db.from('courts').select(
            'id,name,address,city,state,country,lat,lng,radius_meters,is_active,created_at',
          );

      if (_activeOnly) {
        query = query.eq('is_active', true);
      }

      if (q.isNotEmpty) {
        // Search across a few text columns (case-insensitive)
        final escaped = q.replaceAll('"', r'\"');
        query = query.or(
          'name.ilike.%$escaped%,address.ilike.%$escaped%,city.ilike.%$escaped%,state.ilike.%$escaped%,country.ilike.%$escaped%',
        );
      }

      // Apply ordering last (transform)
      final data = await query.order('created_at', ascending: false);
      final list = (data as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _courts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _loadCourts();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim();

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
      body: Column(
        children: [
          _controlsHeader(
            context: context,
            searchCtrl: _searchCtrl,
            activeOnly: _activeOnly,
            onActiveOnlyChanged: (v) {
              setState(() => _activeOnly = v);
              _loadCourts();
            },
            onClear: _clearSearch,
          ),
          Expanded(
            child: _buildBody(context, q),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, String q) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32),
              const SizedBox(height: 8),
              Text(
                'Could not load courts.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadCourts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_courts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No courts found.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                q.isEmpty
                    ? 'Try refreshing.'
                    : 'No results for "$q". Try a different search.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadCourts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  if (q.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear search'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: _courts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = _courts[index];

        final name = (c['name'] ?? 'Unnamed court').toString();
        final address = (c['address'] ?? '').toString();
        final city = (c['city'] ?? '').toString();
        final state = (c['state'] ?? '').toString();
        final country = (c['country'] ?? '').toString();
        final radius = c['radius_meters'];
        final isActive = c['is_active'] == true;

        final locationLine = [
          if (city.isNotEmpty) city,
          if (state.isNotEmpty) state,
          if (country.isNotEmpty) country,
        ].join(', ');

        final subtitleParts = <String>[];
        if (address.isNotEmpty) subtitleParts.add(address);
        if (locationLine.isNotEmpty) subtitleParts.add(locationLine);
        if (radius != null) subtitleParts.add('Radius: ${radius.toString()}m');

        final subtitle = subtitleParts.join(' • ');

        return Card(
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
            onTap: () {
              final id = (c['id'] ?? '').toString();
              if (id.isNotEmpty) {
                context.go('/courts/$id');
              }
            },
          ),
        );
      },
    );
  }
}

Widget _controlsHeader({
  required BuildContext context,
  required TextEditingController searchCtrl,
  required bool activeOnly,
  required ValueChanged<bool> onActiveOnlyChanged,
  required VoidCallback onClear,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Column(
      children: [
        TextField(
          controller: searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search courts (name, city, state...)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchCtrl.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: activeOnly,
                onChanged: onActiveOnlyChanged,
                title: const Text('Active only'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class CourtDetailsPage extends StatefulWidget {
  final String courtId;
  const CourtDetailsPage({super.key, required this.courtId});

  @override
  State<CourtDetailsPage> createState() => _CourtDetailsPageState();
}

class _CourtDetailsPageState extends State<CourtDetailsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _court;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCourt();
  }

  Future<void> _loadCourt() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _db
          .from('courts')
          .select(
            'id,name,address,city,state,country,lat,lng,radius_meters,is_active,created_at',
          )
          .eq('id', widget.courtId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _court = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Court Details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCourt,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32),
              const SizedBox(height: 8),
              Text(
                'Could not load court.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadCourt,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final c = _court;
    if (c == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Court not found.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to courts'),
              ),
            ],
          ),
        ),
      );
    }

    final name = (c['name'] ?? 'Unnamed court').toString();
    final address = (c['address'] ?? '').toString();
    final city = (c['city'] ?? '').toString();
    final state = (c['state'] ?? '').toString();
    final country = (c['country'] ?? '').toString();
    final lat = c['lat'];
    final lng = c['lng'];
    final radius = c['radius_meters'];
    final isActive = c['is_active'] == true;
    final id = (c['id'] ?? '').toString();

    final locationLine = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sports_basketball,
              size: 28,
              color: isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Chip(label: Text(isActive ? 'Active' : 'Inactive')),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _kvRow('Address', address.isEmpty ? '—' : address),
                _kvRow('Location', locationLine.isEmpty ? '—' : locationLine),
                _kvRow('Latitude', lat == null ? '—' : lat.toString()),
                _kvRow('Longitude', lng == null ? '—' : lng.toString()),
                _kvRow('Radius (meters)',
                    radius == null ? '—' : radius.toString()),
                _kvRow('Court ID', id),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Next upgrades will go here (Check-in, map, queue, etc.).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _kvRow(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
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
