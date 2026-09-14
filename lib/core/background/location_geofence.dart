import 'package:native_geofence/native_geofence.dart';

import '../../data/services/location_service.dart';

/// Fixed id for the single "current zone" geofence — there's only ever one
/// active at a time, re-centered on the user each time they leave it (see
/// [LocationGeofenceManager.recenterAround]). Not a per-city catalog.
const String kLocationZoneId = 'enervara-current-zone';

/// Radius of the zone the user has to leave before a new fix is captured —
/// "city-scale" per the product ask ("move out of their city or a specific
/// zone"), tune here if a tighter/looser definition is wanted. 15km covers
/// most single-city travel without false-triggering on a normal commute.
const double kLocationZoneRadiusMeters = 15000;

/// Runs in a separate background isolate when the OS reports the user left
/// (or re-entered) the current geofence — native_geofence bootstraps the
/// isolate itself before calling this, so no manual
/// `WidgetsFlutterBinding.ensureInitialized()` is needed here (unlike a raw
/// platform-channel background entry point).
///
/// Kept top-level + `@pragma('vm:entry-point')` per the plugin's
/// requirements (mandatory for a release/obfuscated build to find this as an
/// entry point at all).
@pragma('vm:entry-point')
Future<void> locationGeofenceCallback(GeofenceCallbackParams params) async {
  if (params.event != GeofenceEvent.exit) return;
  // Take a fresh, accurate fix rather than trusting the geofence event's own
  // (coarser, sometimes-null-on-iOS) location — then re-center the zone on
  // it so the next trigger only fires once the user moves again.
  final snapshot = await LocationService.instance.captureAndPersist();
  if (snapshot != null) {
    await LocationGeofenceManager.recenterAround(
      Location(latitude: snapshot.latitude, longitude: snapshot.longitude),
    );
  }
}

/// Thin wrapper around native_geofence's init/register/cancel calls, kept
/// alongside [locationGeofenceCallback] so every geofencing touchpoint for
/// this feature lives in one file.
class LocationGeofenceManager {
  LocationGeofenceManager._();

  /// Call once at app boot (main.dart), before any geofence is registered —
  /// cheap and idempotent on the plugin's side.
  static Future<void> initialize() => NativeGeofenceManager.instance.initialize();

  /// (Re-)creates the single current-zone geofence centered on [center].
  /// Only `exit` is registered — re-entering the same zone isn't
  /// interesting, and every exit immediately re-centers a fresh zone on the
  /// user's new position, so there's never a need to also watch `enter`.
  ///
  /// A large `notificationResponsiveness` trades a little promptness for a
  /// meaningful battery saving — per native_geofence's own docs, this is the
  /// single biggest lever for background geofencing's power draw.
  static Future<void> recenterAround(Location center) async {
    // Clear any previous zone first — createGeofence with a reused id would
    // otherwise just overwrite it, but an explicit remove keeps this correct
    // even if the id/radius scheme ever changes.
    await _safeRemove();
    await NativeGeofenceManager.instance.createGeofence(
      Geofence(
        id: kLocationZoneId,
        location: center,
        radiusMeters: kLocationZoneRadiusMeters,
        triggers: const {GeofenceEvent.exit},
        iosSettings: const IosGeofenceSettings(initialTrigger: false),
        androidSettings: const AndroidGeofenceSettings(
          initialTriggers: {},
          notificationResponsiveness: Duration(minutes: 5),
        ),
      ),
      locationGeofenceCallback,
    );
  }

  /// Stops continuous monitoring entirely (switching to "only when app is
  /// open" or "don't allow").
  static Future<void> cancel() => _safeRemove();

  static Future<void> _safeRemove() async {
    try {
      await NativeGeofenceManager.instance.removeGeofenceById(kLocationZoneId);
    } on NativeGeofenceException catch (e) {
      // Nothing registered yet — expected on first-ever enable, not an error.
      if (e.code != NativeGeofenceErrorCode.geofenceNotFound) rethrow;
    }
  }
}
