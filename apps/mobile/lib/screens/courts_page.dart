import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

enum CourtSort {
  nameAsc,
  nameDesc,
  cityAsc,
  cityDesc,
}

extension CourtSortLabel on CourtSort {
  String get label {
    switch (this) {
      case CourtSort.nameAsc:
        return 'Name (A–Z)';
      case CourtSort.nameDesc:
        return 'Name (Z–A)';
      case CourtSort.cityAsc:
        return 'City (A–Z)';
      case CourtSort.cityDesc:
        return 'City (Z–A)';
    }
  }
}

class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  bool _loading = false;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _courts = [];

  CourtSort _sort = CourtSort.nameAsc;
  bool _filterActiveOnly = false;
  bool _filterHasRadius = false;

  // Cooldown tracking per court (by courtId)
  static const int cooldownMinutes = 10;
  final Map<String, DateTime> _lastCheckinUtcByCourtId = {};
  Timer? _tick;
  DateTime _nowUtc = DateTime.now().toUtc();

  // DEV: Fake GPS anchor (Test Court 1)
  bool _devFakeGpsEnabled = true;
  static const double _devLat = 32.448800;
  static const double _devLng = -81.783200;

  // Cache current position so we don’t request every build
  _LatLng? _current;
  DateTime? _currentFetchedAtUtc;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureSignedIn();
      await _loadCourts();
      await _loadLastCheckinsForVisibleCourts();
      await _refreshCurrentLocation(force: true);
      _ensureTicker();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _ensureSignedIn() async {
    final current = supabase.auth.currentUser;
    if (current != null) return;
    await supabase.auth.signInAnonymously();
  }

  Future<void> _loadCourts() async {
    final res = await supabase
        .from('courts')
        .select('*')
        .order('name', ascending: true);

    final rows = (res as List).cast<Map<String, dynamic>>();
    _courts = rows;
  }

  int? _readInt(Map<String, dynamic> obj, List<String> keys) {
    for (final k in keys) {
      final v = obj[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> obj, List<String> keys) {
    for (final k in keys) {
      final v = obj[k];
      if (v == null) continue;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool _isActive(Map<String, dynamic> c) {
    final v = c['is_active'];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  bool _hasRadius(Map<String, dynamic> c) {
    final r = _readInt(c, ['radius_meters']);
    return r != null && r > 0;
  }

  String _courtId(Map<String, dynamic> c) => (c['id'] ?? '').toString();
  String _courtName(Map<String, dynamic> c) => (c['name'] ?? '').toString();
  String _courtCity(Map<String, dynamic> c) => (c['city'] ?? '').toString();
  String _courtState(Map<String, dynamic> c) => (c['state'] ?? '').toString();

  _LatLng? _courtLatLng(Map<String, dynamic> c) {
    final lat = _readDouble(c, ['lat', 'latitude']);
    final lng = _readDouble(c, ['lng', 'lon', 'longitude']);
    if (lat == null || lng == null) return null;
    return _LatLng(lat, lng);
  }

  Future<void> _loadLastCheckinsForVisibleCourts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final ids = _courts
        .map(_courtId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (ids.isEmpty) return;

    final res = await supabase
        .from('checkins')
        .select('court_id, created_at')
        .eq('user_id', user.id)
        .inFilter('court_id', ids)
        .order('created_at', ascending: false);

    final rows = (res as List).cast<Map<String, dynamic>>();

    _lastCheckinUtcByCourtId.clear();
    for (final row in rows) {
      final courtId = (row['court_id'] ?? '').toString();
      if (courtId.isEmpty) continue;
      if (_lastCheckinUtcByCourtId.containsKey(courtId)) continue;

      final createdAt = row['created_at'];
      if (createdAt is String) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) _lastCheckinUtcByCourtId[courtId] = dt.toUtc();
      }
    }
  }

  Duration _cooldownRemainingForCourt(String courtId) {
    final last = _lastCheckinUtcByCourtId[courtId];
    if (last == null) return Duration.zero;

    const total = Duration(minutes: cooldownMinutes);
    final diff = _nowUtc.difference(last);
    final remaining = total - diff;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _ensureTicker() {
    _tick?.cancel();

    final anyActive = _lastCheckinUtcByCourtId.entries.any((e) {
      final rem = _cooldownRemainingForCourt(e.key);
      return rem > Duration.zero;
    });

    if (!anyActive) return;

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowUtc = DateTime.now().toUtc();
      if (!mounted) return;

      final stillActive = _lastCheckinUtcByCourtId.entries.any((e) {
        final rem = _cooldownRemainingForCourt(e.key);
        return rem > Duration.zero;
      });

      setState(() {});
      if (!stillActive) _tick?.cancel();
    });
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _filteredSortedCourts() {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<Map<String, dynamic>> items = _courts;

    if (_filterActiveOnly) items = items.where(_isActive);
    if (_filterHasRadius) items = items.where(_hasRadius);

    if (q.isNotEmpty) {
      items = items.where((c) {
        final name = _courtName(c).toLowerCase();
        final city = _courtCity(c).toLowerCase();
        final state = _courtState(c).toLowerCase();
        return name.contains(q) || city.contains(q) || state.contains(q);
      });
    }

    final list = items.toList(growable: false);

    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    list.sort((a, b) {
      switch (_sort) {
        case CourtSort.nameAsc:
          return cmpStr(_courtName(a), _courtName(b));
        case CourtSort.nameDesc:
          return cmpStr(_courtName(b), _courtName(a));
        case CourtSort.cityAsc:
          return cmpStr(_courtCity(a), _courtCity(b));
        case CourtSort.cityDesc:
          return cmpStr(_courtCity(b), _courtCity(a));
      }
    });

    return list;
  }

  Future<void> _openCourt(Map<String, dynamic> c) async {
    final id = _courtId(c);
    if (id.isEmpty) return;

    // Match your router: main.dart shows /courts/:id
    await context.push('/courts/$id');

    // When we come back, reload last check-ins so cooldown pill appears.
    await _loadLastCheckinsForVisibleCourts();
    _ensureTicker();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshCurrentLocation({bool force = false}) async {
    // Throttle updates a bit so we’re not spamming location calls.
    final now = DateTime.now().toUtc();
    if (!force &&
        _current != null &&
        _currentFetchedAtUtc != null &&
        now.difference(_currentFetchedAtUtc!).inSeconds < 5) {
      return;
    }

    if (_devFakeGpsEnabled) {
      _current = const _LatLng(_devLat, _devLng);
      _currentFetchedAtUtc = now;
      return;
    }

    // Real location (may be messy on Windows — that’s why dev anchor exists)
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      _current = _LatLng(pos.latitude, pos.longitude);
      _currentFetchedAtUtc = now;
    } catch (_) {
      // ignore: location can fail on desktop; UI still works.
    }
  }

  double? _distanceMetersToCourt(Map<String, dynamic> c) {
    final me = _current;
    final ll = _courtLatLng(c);
    if (me == null || ll == null) return null;
    return Geolocator.distanceBetween(me.lat, me.lng, ll.lat, ll.lng);
  }

  Future<void> _checkInDirect(Map<String, dynamic> c) async {
    final id = _courtId(c);
    if (id.isEmpty) return;

    await _ensureSignedIn();
    await _refreshCurrentLocation(force: true);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final rem = _cooldownRemainingForCourt(id);
    if (rem > Duration.zero) {
      _toast('Cooldown active: ${_fmt(rem)} remaining.');
      return;
    }

    final radius = _readInt(c, ['radius_meters']) ?? 0;
    final dist = _distanceMetersToCourt(c);
    if (radius > 0 && dist != null && dist > radius) {
      _toast(
          'Not close enough. About ${(dist - radius).ceil()}m outside the radius.');
      return;
    }

    // Insert check-in
    try {
      await supabase.from('checkins').insert({
        'user_id': user.id,
        'court_id': id,
      });

      // ✅ Critical: update local cooldown state immediately so pill shows
      _lastCheckinUtcByCourtId[id] = DateTime.now().toUtc();
      _nowUtc = DateTime.now().toUtc();
      _ensureTicker();

      if (!mounted) return;
      setState(() {});

      _showCheckinSuccessSheet(
          distanceMeters: dist?.round() ?? 0, radius: radius);
    } catch (e) {
      _toast('Check-in failed: $e');
    }
  }

  void _showCheckinSuccessSheet(
      {required int distanceMeters, required int radius}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Checked in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.check_box, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text('Distance: ${distanceMeters}m'),
              Text('Radius required: ${radius}m'),
              const Text('Cooldown: 10 minutes'),
              if (_devFakeGpsEnabled) ...[
                const SizedBox(height: 10),
                const Text(
                  'DEV: Fake GPS enabled for Test Court 1 (desktop debug).',
                  style: TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courts = _filteredSortedCourts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: _devFakeGpsEnabled ? 'DEV anchor ON' : 'DEV anchor OFF',
            onPressed: () async {
              setState(() => _devFakeGpsEnabled = !_devFakeGpsEnabled);
              await _refreshCurrentLocation(force: true);
              if (!mounted) return;
              setState(() {});
            },
            icon: Icon(_devFakeGpsEnabled ? Icons.gps_fixed : Icons.gps_off),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (_devFakeGpsEnabled)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DEV: Fake GPS anchor ON (using Test Court 1 coords)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search courts by name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<CourtSort>(
                        value: _sort,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sort',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: CourtSort.values
                            .map(
                              (s) => DropdownMenuItem<CourtSort>(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _sort = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 10,
                        children: [
                          FilterChip(
                            label: const Text('Active only'),
                            selected: _filterActiveOnly,
                            onSelected: (v) =>
                                setState(() => _filterActiveOnly = v),
                          ),
                          FilterChip(
                            label: const Text('Has radius'),
                            selected: _filterHasRadius,
                            onSelected: (v) =>
                                setState(() => _filterHasRadius = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${courts.length} court${courts.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: courts.isEmpty
                          ? const Center(child: Text('No courts found.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: courts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final c = courts[i];
                                final id = _courtId(c);

                                final name = _courtName(c);
                                final city = _courtCity(c);
                                final state = _courtState(c);

                                final active = _isActive(c);
                                final radius =
                                    _readInt(c, ['radius_meters']) ?? 0;

                                final dist = _distanceMetersToCourt(c);
                                final distLabel =
                                    dist == null ? null : '${dist.round()} m';

                                final inRange = (radius > 0 && dist != null)
                                    ? dist <= radius
                                    : null;

                                final cooldownRem = id.isEmpty
                                    ? Duration.zero
                                    : _cooldownRemainingForCourt(id);
                                final cooldownActive =
                                    cooldownRem > Duration.zero;

                                return InkWell(
                                  onTap: () => _openCourt(c),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          child: Text(
                                            name.isNotEmpty
                                                ? name.characters.first
                                                : '?',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isEmpty ? 'Court' : name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                [city, state]
                                                    .where((s) => s.isNotEmpty)
                                                    .join(', '),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (distLabel != null)
                                                    _pill(context, distLabel),
                                                  if (inRange == true)
                                                    _pill(context, 'IN RANGE'),
                                                  if (inRange == false)
                                                    _pill(context,
                                                        'OUT OF RANGE'),
                                                  if (radius > 0)
                                                    _pill(context,
                                                        '${radius}m radius'),
                                                  if (active)
                                                    _pill(context, 'Active'),
                                                  if (cooldownActive)
                                                    _pill(context,
                                                        'Cooldown ${_fmt(cooldownRem)}'),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  FilledButton.tonalIcon(
                                                    onPressed: cooldownActive
                                                        ? null
                                                        : () =>
                                                            _checkInDirect(c),
                                                    icon:
                                                        const Icon(Icons.login),
                                                    label:
                                                        const Text('Check in'),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  if (inRange == false &&
                                                      dist != null &&
                                                      radius > 0)
                                                    Text(
                                                      'Out of range • ${(dist - radius).round()} m away',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _LatLng {
  final double lat;
  final double lng;
  const _LatLng(this.lat, this.lng);
}
