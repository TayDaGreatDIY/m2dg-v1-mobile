import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/checkin_service.dart';

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
  final _svc = CheckInService(supabase);

  bool _loading = false;
  bool _checkingIn = false;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _courts = [];

  CourtSort _sort = CourtSort.nameAsc;
  bool _filterActiveOnly = false;
  bool _filterHasRadius = false;

  // Cooldown tracking per court (by courtId)
  final Map<String, DateTime> _lastCheckinUtcByCourtId = {};
  Timer? _tick;

  // DEV helper: bypass GPS on desktop while building
  // (Only used in debug mode — safe for MVP build speed.)
  bool _debugPinToCourtCoords = true;

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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _svc.ensureSignedIn();
      await _loadCourts();
      await _loadLastCheckinsForVisibleCourts();
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

  Future<void> _loadCourts() async {
    final res = await supabase
        .from('courts')
        .select('*')
        .order('name', ascending: true);

    final rows = (res as List).cast<Map<String, dynamic>>();
    _courts = rows;
  }

  double? _readDouble(Map<String, dynamic> obj, List<String> keys) {
    for (final k in keys) {
      final v = obj[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
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
    return _svc.computeCooldownRemaining(last);
  }

  void _ensureTicker() {
    _tick?.cancel();

    final anyActive = _lastCheckinUtcByCourtId.keys.any((courtId) {
      final rem = _cooldownRemainingForCourt(courtId);
      return rem > Duration.zero;
    });

    if (!anyActive) return;

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final stillActive = _lastCheckinUtcByCourtId.keys.any((courtId) {
        final rem = _cooldownRemainingForCourt(courtId);
        return rem > Duration.zero;
      });

      setState(() {});
      if (!stillActive) {
        _tick?.cancel();
      }
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

  void _openCourt(Map<String, dynamic> c) {
    final id = _courtId(c);
    if (id.isEmpty) return;
    context.push('/courts/$id'); // matches main.dart route
  }

  Map<String, dynamic>? _findDevAnchorCourt() {
    if (_courts.isEmpty) return null;
    // Prefer a known “Test Court 1” anchor if it exists.
    for (final c in _courts) {
      final name = _courtName(c).toLowerCase();
      if (name.contains('test court 1')) return c;
    }
    return _courts.first;
  }

  int? _distanceMetersFromDevAnchor(Map<String, dynamic> court) {
    if (!(kDebugMode && _debugPinToCourtCoords)) return null;

    final anchor = _findDevAnchorCourt();
    if (anchor == null) return null;

    final aLat = _readDouble(anchor, ['lat', 'latitude']);
    final aLng = _readDouble(anchor, ['lng', 'lon', 'longitude']);
    final cLat = _readDouble(court, ['lat', 'latitude']);
    final cLng = _readDouble(court, ['lng', 'lon', 'longitude']);

    if (aLat == null || aLng == null || cLat == null || cLng == null) {
      return null;
    }

    final d = Geolocator.distanceBetween(aLat, aLng, cLat, cLng);
    if (!d.isFinite) return null;
    return d.round();
  }

  Future<void> _checkInFromList(Map<String, dynamic> c) async {
    if (_checkingIn) return;

    final id = _courtId(c);
    if (id.isEmpty) {
      _toast('Court missing id.');
      return;
    }

    final radius = _readInt(c, ['radius_meters']);
    if (radius == null || radius <= 0) {
      _toast('No radius set for this court.');
      return;
    }

    final lat = _readDouble(c, ['lat', 'latitude']);
    final lng = _readDouble(c, ['lng', 'lon', 'longitude']);
    if (lat == null || lng == null) {
      _toast('Court missing coordinates (lat/lng).');
      return;
    }

    setState(() => _checkingIn = true);

    try {
      final result = await _svc.checkIn(
        courtId: id,
        courtLat: lat,
        courtLng: lng,
        radiusMeters: radius,
        debugPinToCourtCoords: _debugPinToCourtCoords,
      );

      if (!mounted) return;

      _toast(result.message);

      if (result.lastCheckinUtc != null) {
        _lastCheckinUtcByCourtId[id] = result.lastCheckinUtc!;
        _ensureTicker();
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courts = _filteredSortedCourts();
    final anchorCourt =
        (kDebugMode && _debugPinToCourtCoords) ? _findDevAnchorCourt() : null;
    final anchorName = anchorCourt == null ? null : _courtName(anchorCourt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    const SizedBox(height: 10),

                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search courts by name, city, or state',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Sort
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

                    // Filters + Debug toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Active only'),
                            selected: _filterActiveOnly,
                            onSelected: (v) => setState(() {
                              _filterActiveOnly = v;
                            }),
                          ),
                          FilterChip(
                            label: const Text('Has radius'),
                            selected: _filterHasRadius,
                            onSelected: (v) => setState(() {
                              _filterHasRadius = v;
                            }),
                          ),
                          if (kDebugMode)
                            FilterChip(
                              label: const Text('DEV: Pin to court coords'),
                              selected: _debugPinToCourtCoords,
                              onSelected: (v) => setState(() {
                                _debugPinToCourtCoords = v;
                              }),
                            ),
                        ],
                      ),
                    ),

                    if (kDebugMode &&
                        _debugPinToCourtCoords &&
                        anchorName != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DEV anchor: $anchorName',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Count
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

                    // List
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
                                final radius = _readInt(c, ['radius_meters']);

                                final dist = _distanceMetersFromDevAnchor(c);
                                final inRange = (dist != null && radius != null)
                                    ? dist <= radius
                                    : null;

                                final cooldownRem = id.isEmpty
                                    ? Duration.zero
                                    : _cooldownRemainingForCourt(id);
                                final cooldownActive =
                                    cooldownRem > Duration.zero;

                                final canCheckIn = !_checkingIn &&
                                    radius != null &&
                                    radius > 0 &&
                                    id.isNotEmpty;

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
                                                  if (dist != null)
                                                    _pill(context, '$dist m'),
                                                  if (inRange == true)
                                                    _pill(context, 'IN RANGE'),
                                                  if (radius != null &&
                                                      radius > 0)
                                                    _pill(context,
                                                        '$radius m radius'),
                                                  if (active)
                                                    _pill(context, 'Active'),
                                                  if (cooldownActive)
                                                    _pill(context,
                                                        'Cooldown ${_fmt(cooldownRem)}'),
                                                ],
                                              ),
                                              if (dist != null &&
                                                  inRange == false &&
                                                  radius != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8),
                                                  child: Text(
                                                    'Out of range • $dist m away',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Actions
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            FilledButton.tonal(
                                              onPressed: canCheckIn
                                                  ? () => _checkInFromList(c)
                                                  : null,
                                              child: _checkingIn
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    )
                                                  : const Text('Check in'),
                                            ),
                                            const SizedBox(height: 6),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
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
