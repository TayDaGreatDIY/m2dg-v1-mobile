import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  bool _loading = false;
  bool _checkingIn = false;
  String? _error;
  Map<String, dynamic>? _court;

  static const int _cooldownMinutes = 10;

  // Prevent stacking dialogs if user taps fast / multiple returns.
  bool _checkinDialogOpen = false;

  // Cooldown UI state
  DateTime? _lastCheckinUtc;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

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
    await _loadCourt();
    await _loadLastCheckinAndStartTimer();
  }

  Future<void> _loadCourt() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await supabase
          .from('courts')
          .select('*')
          .eq('id', widget.courtId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _court = res;
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

  Future<bool> _ensureSignedIn() async {
    final current = supabase.auth.currentUser;
    if (current != null) return true;

    try {
      await supabase.auth.signInAnonymously();
      return supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ----------------------------
  // DEV: Fake GPS (Windows/Web)
  // ----------------------------
  bool get _devFakeGpsEnabled {
    // Only if explicitly enabled in .env
    final flag = (dotenv.env['DEV_FAKE_GPS'] ?? '').toLowerCase();
    if (flag != 'true' && flag != '1' && flag != 'yes') return false;

    // Only on desktop/web so we don't accidentally ship this behavior to phones
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    return kIsWeb || isWindows;
  }

  bool _isTestCourt1(Map<String, dynamic> c) {
    final name = (c['name'] ?? '').toString().trim().toLowerCase();
    return name == 'test court 1';
  }

  Position _fakePositionForCourt(double lat, double lng) {
    // Create a believable, high-accuracy position right on the court
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 1.0,
    );
  }

  Future<void> _showLocationDialog({
    required String title,
    required String message,
    required Future<void> Function() openSettings,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _requireLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationDialog(
        title: 'Turn on Location',
        message: 'Location is required to check in. Turn on Location Services.',
        openSettings: () async => Geolocator.openLocationSettings(),
      );
      return null;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      _toast('Location permission denied. Check-in requires location.');
      return null;
    }

    if (perm == LocationPermission.deniedForever) {
      await _showLocationDialog(
        title: 'Enable Location Permission',
        message: 'Permission is permanently denied. Enable it in app settings.',
        openSettings: () async => Geolocator.openAppSettings(),
      );
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return pos;
    } catch (e) {
      _toast('Could not get your location. Try again. (${e.toString()})');
      return null;
    }
  }

  Future<DateTime?> _getLastCheckinTime({
    required String userId,
    required String courtId,
  }) async {
    try {
      final res = await supabase
          .from('checkins')
          .select('created_at')
          .eq('user_id', userId)
          .eq('court_id', courtId)
          .order('created_at', ascending: false)
          .limit(1);

      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;

      final createdAt = rows.first['created_at'];
      if (createdAt is String) return DateTime.tryParse(createdAt)?.toUtc();
      return null;
    } catch (_) {
      return null;
    }
  }

  Duration _computeCooldownRemaining(DateTime lastUtc) {
    final nowUtc = DateTime.now().toUtc();
    const cooldown = Duration(minutes: _cooldownMinutes);
    final diff = nowUtc.difference(lastUtc);
    final remaining = cooldown - diff;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = _lastCheckinUtc;
      if (last == null) return;

      final remaining = _computeCooldownRemaining(last);

      if (!mounted) return;
      setState(() => _cooldownRemaining = remaining);

      if (remaining == Duration.zero) {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _loadLastCheckinAndStartTimer() async {
    final okAuth = await _ensureSignedIn();
    final user = supabase.auth.currentUser;
    if (!okAuth || user == null) {
      if (!mounted) return;
      setState(() {
        _lastCheckinUtc = null;
        _cooldownRemaining = Duration.zero;
      });
      return;
    }

    final last = await _getLastCheckinTime(
      userId: user.id,
      courtId: widget.courtId,
    );

    if (!mounted) return;

    setState(() {
      _lastCheckinUtc = last;
      _cooldownRemaining =
          last == null ? Duration.zero : _computeCooldownRemaining(last);
    });

    if (last != null && _cooldownRemaining > Duration.zero) {
      _startCooldownTimer();
    } else {
      _cooldownTimer?.cancel();
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  bool get _cooldownActive => _cooldownRemaining > Duration.zero;

  // Local, human-friendly timestamp (no microseconds)
  String _formatLocalDateTime(DateTime utc) {
    final dt = utc.toLocal();
    const months = [
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
    final month = months[dt.month - 1];
    final day = dt.day;

    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$month $day, $hour:$minute $ampm';
  }

  Future<void> _showStickyCheckinDialog({
    required int radiusMeters,
    required int cooldownMinutes,
    required int distanceMeters,
  }) async {
    if (!mounted) return;
    if (_checkinDialogOpen) return;

    _checkinDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Checked in!')),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: Text(
                '✅ You’re inside the court radius.\n\n'
                'Distance: ${distanceMeters}m\n'
                'Allowed radius: ${radiusMeters}m\n\n'
                'Cooldown started: $cooldownMinutes minutes.\n\n'
                'You can check in again when the cooldown ends.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
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

  Future<void> _handleCheckIn() async {
    if (_checkingIn) return;

    final c = _court;
    if (c == null) {
      _toast('Court not loaded yet.');
      return;
    }

    if (_cooldownActive) {
      _toast(
          'Cooldown active. Try again in ${_formatDuration(_cooldownRemaining)}.');
      return;
    }

    setState(() => _checkingIn = true);

    try {
      final okAuth = await _ensureSignedIn();
      final user = supabase.auth.currentUser;
      if (!okAuth || user == null) {
        _toast('Sign-in required. Enable Anonymous Auth in Supabase.');
        return;
      }

      final radiusMeters = _readInt(c, ['radius_meters']);
      if (radiusMeters == null || radiusMeters <= 0) {
        _toast('No radius set. Add radius_meters in Supabase.');
        return;
      }

      final courtLat = _readDouble(c, ['lat', 'latitude']);
      final courtLng = _readDouble(c, ['lng', 'lon', 'longitude']);
      if (courtLat == null || courtLng == null) {
        _toast('Missing coordinates. Add lat/lng in Supabase.');
        return;
      }

      // Re-check cooldown using DB time (source of truth)
      final last =
          await _getLastCheckinTime(userId: user.id, courtId: widget.courtId);
      if (last != null) {
        final remaining = _computeCooldownRemaining(last);
        if (remaining > Duration.zero) {
          if (!mounted) return;
          setState(() {
            _lastCheckinUtc = last;
            _cooldownRemaining = remaining;
          });
          _startCooldownTimer();
          _toast(
              'Cooldown active. Try again in ${_formatDuration(remaining)}.');
          return;
        }
      }

      // DEV override: if enabled AND this is Test Court 1, fake location at court coords
      final bool useFake = _devFakeGpsEnabled && _isTestCourt1(c);
      final Position? pos = useFake
          ? _fakePositionForCourt(courtLat, courtLng)
          : await _requireLocation();

      if (pos == null) return;

      if (!useFake) {
        // Web/Windows GPS can be sloppy; allow a higher threshold there.
        const maxAccuracyMeters = kIsWeb ? 200.0 : 80.0;

        if (pos.accuracy > maxAccuracyMeters) {
          _toast(
            'GPS accuracy too low (${pos.accuracy.toStringAsFixed(0)}m). Try again.',
          );
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

      await _loadLastCheckinAndStartTimer();

      await _showStickyCheckinDialog(
        radiusMeters: radiusMeters,
        cooldownMinutes: _cooldownMinutes,
        distanceMeters: distance.round(),
      );
    } catch (e) {
      _toast('Check-in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _court;
    final title = (c?['name'] ?? 'Court Details').toString();

    final courtLat = c == null ? null : _readDouble(c, ['lat', 'latitude']);
    final courtLng =
        c == null ? null : _readDouble(c, ['lng', 'lon', 'longitude']);

    final checkinLabel = _checkingIn
        ? 'Checking in...'
        : _cooldownActive
            ? 'Cooldown: ${_formatDuration(_cooldownRemaining)}'
            : 'Check in';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: const BackButton(),
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
                  ? const Center(child: Text('Court not found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _kv('Name', (c['name'] ?? '').toString()),
                        _kv('City', (c['city'] ?? '').toString()),
                        _kv('State', (c['state'] ?? '').toString()),
                        _kv('Radius (meters)', '${c['radius_meters'] ?? ''}'),
                        _kv('Active', '${c['is_active'] ?? ''}'),
                        _kv(
                          'Coordinates',
                          (courtLat != null && courtLng != null)
                              ? '${courtLat.toStringAsFixed(6)}, ${courtLng.toStringAsFixed(6)}'
                              : '',
                        ),
                        const SizedBox(height: 14),
                        _CooldownCard(
                          lastCheckinUtc: _lastCheckinUtc,
                          cooldownRemaining: _cooldownRemaining,
                          cooldownMinutes: _cooldownMinutes,
                          formatLocalDateTime: _formatLocalDateTime,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: (_checkingIn || _cooldownActive)
                              ? null
                              : _handleCheckIn,
                          icon: _checkingIn
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: Text(checkinLabel),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Step C rules: Location required • Must be inside radius • ${_cooldownMinutes}m cooldown',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (_devFakeGpsEnabled && _isTestCourt1(c)) ...[
                          const SizedBox(height: 10),
                          Text(
                            'DEV: Fake GPS enabled for Test Court 1 (using court coords as your location).',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _kv(String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _CooldownCard extends StatelessWidget {
  const _CooldownCard({
    required this.lastCheckinUtc,
    required this.cooldownRemaining,
    required this.cooldownMinutes,
    required this.formatLocalDateTime,
  });

  final DateTime? lastCheckinUtc;
  final Duration cooldownRemaining;
  final int cooldownMinutes;
  final String Function(DateTime utc) formatLocalDateTime;

  String _fmtDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final active = cooldownRemaining > Duration.zero;
    final total = Duration(minutes: cooldownMinutes);

    final progress = active
        ? (1.0 - (cooldownRemaining.inSeconds / total.inSeconds))
            .clamp(0.0, 1.0)
        : 1.0;

    final lastText = lastCheckinUtc == null
        ? 'No check-ins yet'
        : formatLocalDateTime(lastCheckinUtc!);

    final status = active
        ? 'Cooldown active: ${_fmtDuration(cooldownRemaining)} remaining'
        : 'Ready to check in';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Check-in status',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Last check-in: $lastText'),
          const SizedBox(height: 6),
          Text(status),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            'Cooldown length: $cooldownMinutes minutes',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
