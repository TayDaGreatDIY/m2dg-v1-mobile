import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CourtDetailsPage extends StatefulWidget {
  const CourtDetailsPage({super.key, required this.courtId});

  final String courtId;

  @override
  State<CourtDetailsPage> createState() => _CourtDetailsPageState();
}

class _CourtDetailsPageState extends State<CourtDetailsPage> {
  // ---- Step C rules
  static const int _cooldownMinutes = 10;

  bool _loading = false;
  bool _checkingIn = false;
  String? _error;

  Map<String, dynamic>? _court;

  // Cooldown UI state
  DateTime? _lastCheckinUtc;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

  // Activity
  int _myTotalCheckinsHere = 0;
  List<Map<String, dynamic>> _recentCheckins = [];

  // Prevent stacking dialogs if user taps fast
  bool _checkinDialogOpen = false;

  // DEV: fake GPS (desktop debug) for Test Court 1
  // Uses the court’s stored lat/lng as the user position.
  bool get _devFakeGpsEnabled {
    final name = (_court?['name'] ?? '').toString().trim().toLowerCase();
    return kDebugMode && name == 'test court 1';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureSignedIn();
      await _loadCourt();
      await _loadMyActivity();
      await _loadLastCheckinAndStartTimer();

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

  Future<void> _loadCourt() async {
    final res = await supabase
        .from('courts')
        .select('*')
        .eq('id', widget.courtId)
        .maybeSingle();
    if (res == null) {
      throw Exception('Court not found for id: ${widget.courtId}');
    }
    _court = (res as Map).cast<String, dynamic>();
  }

  // ---- helpers to safely read DB fields
  String _s(dynamic v) => (v ?? '').toString();

  bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double? _readLat(Map<String, dynamic> c) =>
      _d(c['lat']) ??
      _d(c['latitude']) ??
      _d(c['court_lat']) ??
      _d(c['courtLatitude']);

  double? _readLng(Map<String, dynamic> c) =>
      _d(c['lng']) ??
      _d(c['longitude']) ??
      _d(c['court_lng']) ??
      _d(c['courtLongitude']);

  int _radiusMeters(Map<String, dynamic> c) =>
      _i(c['radius_meters']) ?? _i(c['radius']) ?? 0;

  // ---- cooldown
  Duration _cooldownRemainingFrom(DateTime? lastUtc) {
    if (lastUtc == null) return Duration.zero;

    const total = Duration(minutes: _cooldownMinutes);
    final diff = DateTime.now().toUtc().difference(lastUtc);
    final remaining = total - diff;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _loadLastCheckinAndStartTimer() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('checkins')
        .select('created_at')
        .eq('user_id', user.id)
        .eq('court_id', widget.courtId)
        .order('created_at', ascending: false)
        .limit(1);

    final rows = (res as List).cast<Map<String, dynamic>>();

    DateTime? lastUtc;
    if (rows.isNotEmpty) {
      final createdAt = rows.first['created_at'];
      if (createdAt is String) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) lastUtc = dt.toUtc();
      }
    }

    _lastCheckinUtc = lastUtc;
    _cooldownRemaining = _cooldownRemainingFrom(_lastCheckinUtc);

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _cooldownRemainingFrom(_lastCheckinUtc);
      if (!mounted) return;

      setState(() => _cooldownRemaining = next);

      if (next == Duration.zero) {
        _cooldownTimer?.cancel();
      }
    });
  }

  String _fmtDuration(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ---- activity
  Future<void> _loadMyActivity() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final countRes = await supabase
        .from('checkins')
        .select('id')
        .eq('user_id', user.id)
        .eq('court_id', widget.courtId);

    _myTotalCheckinsHere = (countRes as List).length;

    final recentRes = await supabase
        .from('checkins')
        .select('created_at, user_id')
        .eq('court_id', widget.courtId)
        .order('created_at', ascending: false)
        .limit(5);

    _recentCheckins = (recentRes as List).cast<Map<String, dynamic>>();
  }

  // ---- UI toast/snackbar
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- location permission + reading
  Future<Position?> _requireLocation() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      _toast('Location services are off. Turn them on and try again.');
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Location permission denied.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        _toast('Could not read location. Try again.');
        return null;
      }
    }
  }

  Position _fakePositionForCourt(double lat, double lng) {
    // A valid Position object for geolocator.
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  // ---- check-in flow
  Future<void> _handleCheckIn() async {
    if (_checkingIn) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      _toast('Not signed in.');
      return;
    }

    final c = _court;
    if (c == null) return;

    final radiusMeters = _radiusMeters(c);
    final courtLat = _readLat(c);
    final courtLng = _readLng(c);

    if (courtLat == null || courtLng == null) {
      _toast('Court is missing coordinates.');
      return;
    }

    // Cooldown gate
    final remaining = _cooldownRemainingFrom(_lastCheckinUtc);
    if (remaining > Duration.zero) {
      _toast('Cooldown active. Try again in ${_fmtDuration(remaining)}.');
      return;
    }

    setState(() => _checkingIn = true);

    try {
      // DEV: If Test Court 1 on desktop debug, skip real location and use court coords.
      Position? pos;
      if (_devFakeGpsEnabled) {
        pos = _fakePositionForCourt(courtLat, courtLng);
      } else {
        pos = await _requireLocation();
      }

      if (pos == null) return;

      // Accuracy gate (skip if DEV fake GPS)
      if (!_devFakeGpsEnabled) {
        const isWeb = kIsWeb;
        final isDesktop = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux);

        // Web/desktop GPS can be sloppy.
        final maxAccuracyMeters = (isWeb || isDesktop) ? 200.0 : 80.0;

        if (pos.accuracy > maxAccuracyMeters) {
          _toast(
              'GPS accuracy too low (${pos.accuracy.toStringAsFixed(0)}m). Try again.');
          return;
        }
      }

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        courtLat,
        courtLng,
      );

      if (distance > radiusMeters) {
        final away = (distance - radiusMeters).ceil();
        _toast('Not close enough. About ${away}m outside the radius.');
        return;
      }

      await supabase.from('checkins').insert({
        'user_id': user.id,
        'court_id': widget.courtId,
      });

      await _loadMyActivity();
      await _loadLastCheckinAndStartTimer();

      if (!mounted) return;

      await _showStickyCheckinDialog(
        radiusMeters: radiusMeters,
        cooldownMinutes: _cooldownMinutes,
        distanceMeters: distance.round(),
      );
    } catch (e) {
      _toast('Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _showStickyCheckinDialog({
    required int radiusMeters,
    required int cooldownMinutes,
    required int distanceMeters,
  }) async {
    if (_checkinDialogOpen) return;
    _checkinDialogOpen = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Checked in ✅',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('Distance', '${distanceMeters}m'),
                _kv('Radius required', '${radiusMeters}m'),
                _kv('Cooldown', '$cooldownMinutes minutes'),
                if (_devFakeGpsEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'DEV: Fake GPS enabled for Test Court 1 (desktop debug).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _checkinDialogOpen = false;
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Text(v, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  // ---- UI blocks
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _card(
      {required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _court;

    final name = c == null ? '' : _s(c['name']);
    final city = c == null ? '' : _s(c['city']);
    final state = c == null ? '' : _s(c['state']);
    final radius = c == null ? 0 : _radiusMeters(c);
    final active = c == null ? false : _b(c['is_active']);
    final lat = c == null ? null : _readLat(c);
    final lng = c == null ? null : _readLng(c);

    final cooldownActive = _cooldownRemaining > Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Court' : name),
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
              : c == null
                  ? const Center(child: Text('Court not loaded.'))
                  : Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _infoRow('Name', name),
                            _infoRow('City', city),
                            _infoRow('State', state),
                            _infoRow('Radius (meters)', radius.toString()),
                            _infoRow('Active', active.toString()),
                            _infoRow(
                              'Coordinates',
                              (lat != null && lng != null)
                                  ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                                  : '—',
                            ),
                            const SizedBox(height: 16),
                            _card(
                              title: 'Check-in status',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastCheckinUtc == null
                                        ? 'Last check-in: —'
                                        : 'Last check-in: ${_formatLocal(_lastCheckinUtc!)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cooldownActive
                                        ? 'Cooldown active: ${_fmtDuration(_cooldownRemaining)} remaining'
                                        : 'Ready to check in',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: cooldownActive
                                        ? 1 -
                                            (_cooldownRemaining.inSeconds /
                                                (const Duration(
                                                        minutes:
                                                            _cooldownMinutes))
                                                    .inSeconds)
                                        : 1,
                                    minHeight: 4,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cooldown length: $_cooldownMinutes minutes',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _card(
                              title: 'Activity',
                              trailing: IconButton(
                                tooltip: 'Refresh activity',
                                onPressed: () async {
                                  await _loadMyActivity();
                                  if (!mounted) return;
                                  setState(() {});
                                },
                                icon: const Icon(Icons.refresh),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Your total check-ins here: $_myTotalCheckinsHere'),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Recent check-ins (last 5)',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_recentCheckins.isEmpty)
                                    const Text('No check-ins yet.')
                                  else
                                    ..._recentCheckins.map((r) {
                                      final createdAt = r['created_at'];
                                      DateTime? dt;
                                      if (createdAt is String) {
                                        dt = DateTime.tryParse(createdAt);
                                      }
                                      final who = _s(r['user_id']) ==
                                              (supabase.auth.currentUser?.id ??
                                                  '')
                                          ? 'You'
                                          : '';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.people, size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                dt == null
                                                    ? '—'
                                                    : '${_formatLocal(dt.toUtc())}${who.isEmpty ? '' : ' — $who'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Step C rules: Location required • Must be inside radius • ${_cooldownMinutes}m cooldown',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_devFakeGpsEnabled) ...[
                              const SizedBox(height: 6),
                              Text(
                                'DEV: Fake GPS enabled for Test Court 1 (using court coords as your location).',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 90),
                          ],
                        ),

                        // Bottom check-in bar
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: (_checkingIn || _loading)
                                    ? null
                                    : _handleCheckIn,
                                icon: const Icon(Icons.login),
                                label: Text(_checkingIn
                                    ? 'Checking in...'
                                    : 'Check in'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  String _formatLocal(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hh = ((h + 11) % 12) + 1;
    return '${_mon(local.month)} ${local.day}, $hh:$m $ampm';
  }

  String _mon(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[(m - 1).clamp(0, 11)];
  }
}
