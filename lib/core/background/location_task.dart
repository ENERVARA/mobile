import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/services/location_service.dart';

/// Unique WorkManager task id. MUST match, byte-for-byte, three other
/// places: `ios/Runner/Info.plist`'s `BGTaskSchedulerPermittedIdentifiers`
/// entry, the `SwiftWorkmanagerPlugin.registerPeriodicTask` call in
/// `ios/Runner/AppDelegate.swift`, and is used verbatim as both the
/// `uniqueName` and `taskName` args below (Android keys work off
/// `uniqueName`, iOS off this identifier — passing the same string for both
/// keeps one constant to keep in sync instead of two).
const String kLocationTaskId = 'com.enervara.enervara.locationRefresh';

/// Runs in a separate background isolate (Android: a WorkManager Worker;
/// iOS: a BGAppRefreshTask) — nothing from the main isolate/app state is
/// available here, [LocationService] talks to `SharedPreferences` and
/// `geolocator` directly rather than through Riverpod.
///
/// Kept top-level + `@pragma('vm:entry-point')` per workmanager's
/// requirements (mandatory for a release/obfuscated build to find this as an
/// entry point at all).
@pragma('vm:entry-point')
void locationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kLocationTaskId) {
      await LocationService.instance.captureAndPersist();
    }
    // Always report success — a denied permission or a timed-out fix is a
    // normal outcome (handled/swallowed inside captureAndPersist), not a
    // failure Android should burn retry-with-backoff attempts on.
    return true;
  });
}

/// Thin wrapper around the plugin's init/schedule/cancel calls, kept
/// alongside [locationCallbackDispatcher] so every workmanager touchpoint
/// for this feature lives in one file.
class LocationBackgroundTask {
  LocationBackgroundTask._();

  /// Call once at app boot (main.dart), before any scheduling — cheap and
  /// idempotent on the plugin's side.
  static Future<void> initialize() {
    return Workmanager().initialize(
      locationCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Registers the recurring capture. Safe to call on every app boot/login —
  /// `ExistingPeriodicWorkPolicy.keep` makes re-registering a no-op if a
  /// matching task is already scheduled, so this never resets the 24h clock
  /// or double-schedules. `frequency`/`constraints` only take effect on
  /// Android; iOS's actual cadence is fixed in AppDelegate.swift and is
  /// opportunistic regardless (see the policy note below).
  ///
  /// ── Play Store / App Store background-location note ─────────────────────
  /// This task exists to detect recent travel so Nova can give more accurate
  /// guidance for travel-related symptoms, and (planned) to power a "nearby
  /// doctors" feature. That's the justification to use verbatim in Play
  /// Console's "Background location" permission declaration and in the
  /// privacy policy — Google/Apple reject vague justifications for this
  /// permission, and reviewers do check the two match.
  static Future<void> schedule() {
    return Workmanager().registerPeriodicTask(
      kLocationTaskId,
      kLocationTaskId,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        // Local-only capture right now (see LocationService.captureAndPersist's
        // TODO) — no network needed yet. Flip to NetworkType.connected once
        // the backend send is wired in, so a run without connectivity defers
        // instead of capturing a point it can't sync.
        networkType: NetworkType.not_required,
      ),
    );
  }

  static Future<void> cancel() {
    return Workmanager().cancelByUniqueName(kLocationTaskId);
  }
}
