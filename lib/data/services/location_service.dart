import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart' as geofence;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/background/location_geofence.dart';
import '../models/user_location.dart';

/// The three access tiers offered in the location prompt/toggle.
enum LocationAccessMode {
  /// Background geofencing — the OS wakes the app when the user leaves their
  /// current zone, even if it's closed. Needs "always"/background permission.
  continuous,

  /// Only captured while the app itself is open (on each foreground resume).
  /// Needs foreground ("while in use") permission only — no background
  /// permission is ever requested for this tier.
  whileInUse,

  /// Location is never read. No permission is requested.
  off;

  static LocationAccessMode fromStored(String? raw) {
    return LocationAccessMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => LocationAccessMode.off,
    );
  }
}

/// Why [LocationService.setMode] landed on a different tier than requested
/// (or on the same tier but worth flagging). `null` from `setMode` itself
/// means it landed exactly on what was requested.
enum LocationSetModeIssue {
  /// The device's location services (GPS/network location) are off entirely
  /// — an OS-level toggle, not a per-app permission.
  servicesDisabled,

  /// The user denied the permission dialog (or it's permanently denied and
  /// the OS won't show it again without a trip through Settings).
  permissionDenied,

  /// Permission was granted, but a position fix couldn't be obtained in
  /// time — e.g. an emulator with no mock location set, weak/no GPS signal,
  /// or Play Services unavailable. NOT a permission problem.
  fixFailed,

  /// Foreground ("while in use") was granted, but the OS wouldn't escalate
  /// to background ("always") from the in-app prompt — most Android 11+
  /// builds require that specific upgrade to go through system Settings.
  backgroundEscalationNeeded,
}

class LocationSetModeResult {
  final LocationAccessMode mode;
  final LocationSetModeIssue? issue;
  const LocationSetModeResult(this.mode, this.issue);
}

/// Captures + locally persists the device's location, and owns the
/// tri-state access-mode flow (continuous / while-in-use / off) required by
/// Play Store and App Store review for background location — see the policy
/// note on [LocationGeofenceManager].
///
/// NOT wired to the backend yet. [captureAndPersist] is the single place a
/// future `dio.patch(...)` call gets added once a location field/endpoint
/// exists server-side — everything else (permissions, geofencing, the
/// prompt UI) is already complete and independent of that.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  static const _kModeKey = 'enervara_location_mode';
  static const _kDecidedKey = 'enervara_location_decided';
  static const _kLastLatKey = 'enervara_last_location_lat';
  static const _kLastLngKey = 'enervara_last_location_lng';
  static const _kLastAtKey = 'enervara_last_location_at';

  /// True once the user has answered the prompt at least once (any of the
  /// three options, including "Don't allow") — gates ever auto-showing it
  /// again; the header toggle button re-opens it on demand regardless.
  Future<bool> hasDecided() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDecidedKey) ?? false;
  }

  /// The currently persisted access mode. Defaults to [LocationAccessMode.off]
  /// before the user has ever chosen (same as after choosing "Don't allow").
  Future<LocationAccessMode> currentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return LocationAccessMode.fromStored(prefs.getString(_kModeKey));
  }

  Future<void> _persistMode(LocationAccessMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDecidedKey, true);
    await prefs.setString(_kModeKey, mode.name);
  }

  /// Applies [requested]: asks the OS for the permission that tier needs,
  /// (de)registers the geofence accordingly, and persists whatever was
  /// *actually* achieved — never claims a tier the OS didn't actually grant,
  /// so the toggle button's colour always reflects reality. The result's
  /// `issue` explains *why* when that differs from what was asked for (e.g.
  /// permission truly denied vs. permission fine but no GPS fix available —
  /// those need very different user-facing messages).
  Future<LocationSetModeResult> setMode(LocationAccessMode requested) async {
    switch (requested) {
      case LocationAccessMode.continuous:
        return _enableContinuous();
      case LocationAccessMode.whileInUse:
        return _enableWhileInUse();
      case LocationAccessMode.off:
        return _disable();
    }
  }

  Future<LocationSetModeResult> _enableContinuous() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _clearBackendLocation();
      return _disable(issue: LocationSetModeIssue.servicesDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _disable(issue: LocationSetModeIssue.permissionDenied);
    }
    // Android intentionally only offers "while in use" on the first prompt;
    // escalating to "always" needs its own explicit second request (the OS
    // shows a separate "Allow all the time" dialog, or routes to Settings on
    // some OEM builds). iOS folds both into the one
    // NSLocationAlwaysAndWhenInUseUsageDescription prompt, so this second
    // call is a same-permission no-op there.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always) {
      // Background wasn't granted, but foreground was — land on the tier
      // that's actually usable rather than silently doing nothing, and say
      // so distinctly from an outright denial.
      final fallback = await _enableWhileInUse();
      return LocationSetModeResult(
        fallback.mode,
        LocationSetModeIssue.backgroundEscalationNeeded,
      );
    }

    final snapshot = await captureAndPersist();
    if (snapshot == null) {
      // Permission was genuinely granted — this is a GPS fix problem, not a
      // permission problem (classic case: an emulator with no mock location
      // set, or a cold/weak GPS signal exceeding the 20s timeout).
      return _disable(issue: LocationSetModeIssue.fixFailed);
    }

    await LocationGeofenceManager.recenterAround(
      geofence.Location(latitude: snapshot.latitude, longitude: snapshot.longitude),
    );
    await _persistMode(LocationAccessMode.continuous);
    return const LocationSetModeResult(LocationAccessMode.continuous, null);
  }

  Future<LocationSetModeResult> _enableWhileInUse() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _clearBackendLocation();
      return _disable(issue: LocationSetModeIssue.servicesDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _disable(issue: LocationSetModeIssue.permissionDenied);
    }

    await LocationGeofenceManager.cancel();
    // A failed first fix here isn't fatal the way it is for "continuous" —
    // the mode still activates and will simply try again next time the app
    // is opened (captureOnResumeIfNeeded), so don't downgrade to "off" over
    // a single timed-out fix.
    await captureAndPersist();
    await _persistMode(LocationAccessMode.whileInUse);
    return const LocationSetModeResult(LocationAccessMode.whileInUse, null);
  }

  Future<LocationSetModeResult> _disable({LocationSetModeIssue? issue}) async {
    await LocationGeofenceManager.cancel();
    await _clearBackendLocation();
    await _persistMode(LocationAccessMode.off);
    return LocationSetModeResult(LocationAccessMode.off, issue);
  }

  /// Call on every app boot/login — re-arms the geofence for a device that
  /// already chose "continuous" on a previous session (e.g. after the app
  /// was reinstalled, or a device reboot the OS failed to re-register
  /// through). No-op for the other two tiers.
  Future<void> rearmIfNeeded() async {
    if (await currentMode() != LocationAccessMode.continuous) return;
    final point = await lastKnown() ?? await captureAndPersist();
    if (point == null) return;
    await LocationGeofenceManager.recenterAround(
      geofence.Location(latitude: point.latitude, longitude: point.longitude),
    );
  }

  /// Called on app resume (foreground) — only takes effect in "while in use"
  /// mode, where a fresh fix is worth taking each time the app is reopened
  /// since there's no background geofence doing it in between.
  Future<void> captureOnResumeIfNeeded() async {
    if (await currentMode() == LocationAccessMode.whileInUse) {
      await captureAndPersist();
    }
  }

  /// Reads the last locally-persisted snapshot, if any.
  Future<UserLocationSnapshot?> lastKnown() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLastLatKey);
    final lng = prefs.getDouble(_kLastLngKey);
    final at = prefs.getString(_kLastAtKey);
    if (lat == null || lng == null || at == null) return null;
    final capturedAt = DateTime.tryParse(at);
    if (capturedAt == null) return null;
    return UserLocationSnapshot(latitude: lat, longitude: lng, capturedAt: capturedAt);
  }

  /// Captures a fresh fix, persists it locally, and mirrors it to the real
  /// backend `/location` endpoint. The app's main `dio` client already adds
  /// the user's bearer token, so the request stays scoped to the signed-in
  /// user without any custom API key or user-id path parameter.
  Future<UserLocationSnapshot?> captureAndPersist() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final snapshot = UserLocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now().toUtc(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLastLatKey, snapshot.latitude);
      await prefs.setDouble(_kLastLngKey, snapshot.longitude);
      await prefs.setString(_kLastAtKey, snapshot.capturedAt.toIso8601String());

      try {
        await _saveLocationToBackend(snapshot);
      } catch (e) {
        debugPrint('LocationService: backend location save failed: $e');
      }

      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<LocationBackendState?> fetchLocationState() async {
    try {
      final res = await dio.get('/location');
      if (res.data is! Map) return null;
      return LocationBackendState.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      debugPrint('LocationService: fetch /location failed: $e');
      return null;
    }
  }

  Future<LocationBackendState?> _saveLocationToBackend(
    UserLocationSnapshot snapshot,
  ) async {
    final res = await dio.put('/location', data: {
      'latitude': snapshot.latitude,
      'longitude': snapshot.longitude,
    });
    if (res.data is! Map) return null;
    return LocationBackendState.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<LocationBackendState?> _clearBackendLocation() async {
    try {
      final res = await dio.delete('/location');
      if (res.data is! Map) return null;
      return LocationBackendState.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      debugPrint('LocationService: delete /location failed: $e');
      return null;
    }
  }
}
