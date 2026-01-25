import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInResult {
  final bool ok;
  final String message;

  final DateTime? lastCheckinUtc;
  final int? distanceMeters;
  final double? accuracyMeters;
  final Duration? cooldownRemaining;

  const CheckInResult({
    required this.ok,
    required this.message,
    this.lastCheckinUtc,
    this.distanceMeters,
    this.accuracyMeters,
    this.cooldownRemaining,
  });
}

class CheckInService {
  final SupabaseClient supabase;

  static const Duration cooldown = Duration(minutes: 10);
  static const double accuracyRequiredMeters = 75; // tune later for Android

  const CheckInService(this.supabase);

  Future<void> ensureSignedIn() async {
    final current = supabase.auth.currentUser;
    if (current != null) return;
    await supabase.auth.signInAnonymously();
  }

  /// UI helper: compute remaining cooldown using "now" internally.
  Duration computeCooldownRemaining(DateTime lastCheckinUtc) {
    final nowUtc = DateTime.now().toUtc();
    return _computeCooldownRemainingAt(lastCheckinUtc, nowUtc);
  }

  /// Internal helper when you already have a "now" timestamp.
  Duration _computeCooldownRemainingAt(
      DateTime lastCheckinUtc, DateTime nowUtc) {
    final diff = nowUtc.difference(lastCheckinUtc);
    final remaining = cooldown - diff;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<CheckInResult> checkIn({
    required String courtId,
    required double courtLat,
    required double courtLng,
    required int radiusMeters,
    required bool debugPinToCourtCoords,
  }) async {
    await ensureSignedIn();

    final user = supabase.auth.currentUser;
    if (user == null) {
      return const CheckInResult(ok: false, message: 'Not signed in.');
    }

    // 1) cooldown check: latest checkin for this user+court
    final latest = await supabase
        .from('checkins')
        .select('created_at')
        .eq('user_id', user.id)
        .eq('court_id', courtId)
        .order('created_at', ascending: false)
        .limit(1);

    DateTime? lastUtc;
    if (latest.isNotEmpty) {
      final createdAt = (latest.first as Map)['created_at'];
      if (createdAt is String) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) lastUtc = dt.toUtc();
      }
    }

    final nowUtc = DateTime.now().toUtc();
    if (lastUtc != null) {
      final remaining = _computeCooldownRemainingAt(lastUtc, nowUtc);
      if (remaining > Duration.zero) {
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        return CheckInResult(
          ok: false,
          message:
              'Cooldown active: $mins:${secs.toString().padLeft(2, '0')} remaining.',
          lastCheckinUtc: lastUtc,
          cooldownRemaining: remaining,
        );
      }
    }

    // 2) location
    Position pos;
    if (kDebugMode && debugPinToCourtCoords) {
      // DEV: pretend your GPS is exactly on the court
      pos = Position(
        latitude: courtLat,
        longitude: courtLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } else {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CheckInResult(
          ok: false,
          message: 'Location services are disabled.',
        );
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const CheckInResult(
            ok: false, message: 'Location permission denied.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const CheckInResult(
          ok: false,
          message: 'Location permission denied forever.',
        );
      }

      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (pos.accuracy.isFinite && pos.accuracy > accuracyRequiredMeters) {
        return CheckInResult(
          ok: false,
          message:
              'GPS accuracy too low (${pos.accuracy.round()}m). Try again.',
          accuracyMeters: pos.accuracy,
        );
      }
    }

    // 3) distance check
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      courtLat,
      courtLng,
    );

    final distanceMeters = dist.isFinite ? dist.round() : null;

    if (dist > radiusMeters) {
      final outsideBy = (dist - radiusMeters).ceil();
      return CheckInResult(
        ok: false,
        message: 'Not close enough. About ${outsideBy}m outside the radius.',
        distanceMeters: distanceMeters,
        accuracyMeters: pos.accuracy,
      );
    }

    // 4) insert checkin
    await supabase.from('checkins').insert({
      'user_id': user.id,
      'court_id': courtId,
    });

    return CheckInResult(
      ok: true,
      message: 'Checked in.',
      lastCheckinUtc: nowUtc,
      distanceMeters: distanceMeters,
      accuracyMeters: pos.accuracy,
      cooldownRemaining: cooldown,
    );
  }

  // optional helper (if you want rounding consistency later)
  int roundMeters(double meters) => meters.isFinite ? meters.round() : 0;

  // not required; kept for potential future UI math
  int clamp(int v, int min, int max) => math.max(min, math.min(max, v));
}
