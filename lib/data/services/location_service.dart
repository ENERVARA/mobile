import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_location.dart';

/// Captures + locally persists the device's location, and owns the one-time
/// background-location consent flow (required by both Play Store and App
/// Store review — see [LocationTaskIdentifier] doc for the full policy note).
///
/// NOT wired to the backend yet. [captureAndPersist] is the single place a
/// future `dio.patch(...)` call gets added once a location field/endpoint
/// exists server-side — everything else (permission flow, scheduling,
/// consent UI) is already complete and independent of that.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  static const _kConsentDecidedKey = 'enervara_location_consent_decided';
  static const _kConsentGrantedKey = 'enervara_location_consent_granted';
  static const _kLastLatKey = 'enervara_last_location_lat';
  static const _kLastLngKey = 'enervara_last_location_lng';
  static const _kLastAtKey = 'enervara_last_location_at';

  /// True once the user has seen the disclosure screen and made a choice
  /// (Enable or Not now) — gates ever showing it again.
  Future<bool> hasDecidedConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentDecidedKey) ?? false;
  }

  Future<bool> isConsentGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentGrantedKey) ?? false;
  }

  Future<void> _setConsent({required bool granted}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentDecidedKey, true);
    await prefs.setBool(_kConsentGrantedKey, granted);
  }

  /// Walks the two-step Android permission flow (foreground first, then a
  /// separate escalation to background) and iOS's single always-usage
  /// prompt. Returns true only if background ("always") access was actually
  /// granted — foreground-only isn't enough for a once-a-day check while the
  /// app is closed.
  Future<bool> requestBackgroundPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    // Android intentionally only offers "while in use" on the first prompt;
    // escalating to "always" needs its own explicit second request (the OS
    // shows an "Allow all the time" dialog, or routes to Settings on some
    // OEM builds). iOS folds both into the one
    // NSLocationAlwaysAndWhenInUseUsageDescription prompt, so this second
    // call is a same-permission no-op there.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always;
  }

  /// Called once, right after the user accepts the disclosure screen.
  /// Persists the consent decision either way, and takes an immediate first
  /// reading on success so there's data before the first 24h task fires.
  Future<bool> grantConsentAndEnable() async {
    final granted = await requestBackgroundPermission();
    await _setConsent(granted: granted);
    if (granted) await captureAndPersist();
    return granted;
  }

  Future<void> declineConsent() => _setConsent(granted: false);

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

  /// Captures a fresh fix and persists it locally. Safe to call from the
  /// WorkManager background isolate — never throws; a background task must
  /// not crash the isolate on a denied permission, disabled location
  /// services, or a timed-out fix, it should just skip quietly until the
  /// next scheduled run.
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

      // TODO(backend): once a location field/endpoint exists on the user
      // record, send `snapshot` here — e.g.
      //   await dio.patch('/location', data: snapshot.toJson());
      // mirrors how PushNotificationService.registerToken() syncs its own
      // device state to the backend after a local capture.

      return snapshot;
    } catch (_) {
      return null;
    }
  }
}
