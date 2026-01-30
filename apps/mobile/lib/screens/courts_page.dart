import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/checkin_service.dart';
import '../services/court_queue_service.dart';
import '../widgets/court_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_list.dart';

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

  // Real-time subscriptions for queue updates
  final Map<String, RealtimeChannel> _queueChannels = {};

  @override
  void initState() {
    super.initState();
    print('🏀 CourtsPage initState - athlete view loaded');
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadAll();
    _setupQueueSubscriptions();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _searchCtrl.dispose();
    // Cleanup subscriptions
    for (final channel in _queueChannels.values) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // Setup real-time queue subscriptions for all courts
  void _setupQueueSubscriptions() {
    try {
      // Subscribe to all court_queues changes
      final channel = supabase
          .channel('courts_queue_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'court_queues',
            callback: (payload) {
              // On any queue change, refresh the courts list to update counts
              if (mounted) {
                setState(() {});
              }
            },
          )
          .subscribe();
      
      _queueChannels['all'] = channel;

      // Also subscribe to checkins changes to update cooldown display
      final checkinsChannel = supabase
          .channel('courts_checkins_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'checkins',
            callback: (payload) {
              // When checkins change, reload to update cooldown display
              if (mounted) {
                _loadLastCheckinsForVisibleCourts();
              }
            },
          )
          .subscribe();

      _queueChannels['checkins'] = checkinsChannel;
    } catch (e) {
      print('Error setting up queue subscriptions: $e');
    }
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _sort = CourtSort.nameAsc;
      _filterActiveOnly = false;
      _filterHasRadius = false;
      // keep dev toggle as-is (don’t auto-change dev workflow)
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Auth is now required, so no need to call ensureSignedIn()
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

  Future<void> _joinQueueFromList(
      Map<String, dynamic> court, BuildContext context) async {
    final id = _courtId(court);
    if (id.isEmpty) {
      _toast('Court missing ID');
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Check if already in queue at this court
      final existingQueue = await supabase
          .from('court_queues')
          .select('id')
          .eq('court_id', id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingQueue != null) {
        _toast('Already in queue for this court');
        return;
      }

      // Remove from all other court queues
      await supabase
          .from('court_queues')
          .delete()
          .eq('user_id', user.id)
          .neq('court_id', id);

      // Join the queue
      await CourtQueueService.joinQueue(id, teamSize: 1);
      _toast('Joined queue! Wait for your turn.');
      setState(() {});
    } catch (e) {
      _toast('Error: $e');
    }
  }

  String _getUserGreeting() {
    final user = supabase.auth.currentUser;
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? "What's good"
            : 'Good evening';
    final userName = user?.userMetadata?['full_name'] ?? 'Baller';
    return '$timeGreeting, $userName!';
  }

  @override
  Widget build(BuildContext context) {
    final courts = _filteredSortedCourts();

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: _buildMinimalAppBar(),
      body: _loading
          ? const SkeletonList(count: 6)
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _loadAll,
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Greeting section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getUserGreeting(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ready to bring the heat?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFFC7C7CC),
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Nearby Courts section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Nearby Courts',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nearby courts cards (show first 3)
                      SizedBox(
                        height: 280,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: courts.length > 3 ? 3 : courts.length,
                          itemBuilder: (context, index) {
                            final court = courts[index];
                            final courtId = _courtId(court);
                            final cooldown =
                                _cooldownRemainingForCourt(courtId);
                            final isOnCooldown = cooldown > Duration.zero;
                            final radius = _readInt(court, ['radius_meters']);
                            final dist =
                                _distanceMetersFromDevAnchor(court);

                            return Container(
                              width: 280,
                              margin: const EdgeInsets.only(right: 12),
                              child: CourtCard(
                                data: CourtCardData(
                                  title: _courtName(court),
                                  subtitle: [_courtCity(court), _courtState(court)]
                                      .where((s) => s.isNotEmpty)
                                      .join(', '),
                                  distanceText: dist != null ? '$dist m' : null,
                                  inRange: (dist != null && radius != null)
                                      ? dist <= radius
                                      : false,
                                  active: _isActive(court),
                                  radiusText: (radius != null && radius > 0)
                                      ? '$radius m radius'
                                      : null,
                                  onTap: () => _openCourt(court),
                                  onCheckIn: !isOnCooldown && !_checkingIn
                                      ? () => _checkInFromList(court)
                                      : null,
                                  onJoinQueue: () =>
                                      _joinQueueFromList(court, context),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // All courts section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Courts',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () => _showSortFilterSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.tune,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMinimalSearch(),
                      ),

                      const SizedBox(height: 12),

                      // Courts list
                      if (courts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.location_off_outlined,
                                  color: const Color(0xFFC7C7CC),
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No courts found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: const Color(0xFFC7C7CC),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: courts.length,
                          itemBuilder: (context, index) {
                            final court = courts[index];
                            final courtId = _courtId(court);
                            final cooldown =
                                _cooldownRemainingForCourt(courtId);
                            final isOnCooldown = cooldown > Duration.zero;
                            final radius = _readInt(court, ['radius_meters']);
                            final dist =
                                _distanceMetersFromDevAnchor(court);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CourtCard(
                                data: CourtCardData(
                                  title: _courtName(court),
                                  subtitle: [_courtCity(court), _courtState(court)]
                                      .where((s) => s.isNotEmpty)
                                      .join(', '),
                                  distanceText: dist != null ? '$dist m' : null,
                                  inRange: (dist != null && radius != null)
                                      ? dist <= radius
                                      : false,
                                  active: _isActive(court),
                                  radiusText: (radius != null && radius > 0)
                                      ? '$radius m radius'
                                      : null,
                                  onTap: () => _openCourt(court),
                                  onCheckIn: !isOnCooldown && !_checkingIn
                                      ? () => _checkInFromList(court)
                                      : null,
                                  onJoinQueue: () =>
                                      _joinQueueFromList(court, context),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildMinimalAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1F1F1F),
      elevation: 0,
      centerTitle: false,
      title: Text(
        'M2DG',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Badge(
              backgroundColor: const Color(0xFFFF2D55),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () {
                  context.pushNamed('notifications');
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalSearch() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search courts...',
        hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFC7C7CC)),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  void _showSortFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sortOption in CourtSort.values)
                  FilterChip(
                    label: Text(sortOption.label),
                    selected: _sort == sortOption,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _sort = sortOption);
                      }
                      Navigator.pop(context);
                    },
                    backgroundColor: const Color(0xFF3A3A3C),
                    selectedColor: const Color(0xFFFF2D55),
                    labelStyle: TextStyle(
                      color: _sort == sortOption
                          ? Colors.white
                          : const Color(0xFFC7C7CC),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Active Only',
                  style: TextStyle(color: Colors.white)),
              value: _filterActiveOnly,
              onChanged: (v) {
                setState(() => _filterActiveOnly = v ?? false);
                Navigator.pop(context);
              },
              checkColor: Colors.white,
              activeColor: const Color(0xFFFF2D55),
            ),
            CheckboxListTile(
              title: const Text('Has Radius',
                  style: TextStyle(color: Colors.white)),
              value: _filterHasRadius,
              onChanged: (v) {
                setState(() => _filterHasRadius = v ?? false);
                Navigator.pop(context);
              },
              checkColor: Colors.white,
              activeColor: const Color(0xFFFF2D55),
            ),
          ],
        ),
      ),
    );
  }
}
