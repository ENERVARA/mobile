import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Daily location check-in (LocationService / lib/core/background/location_task.dart).
    // Per the workmanager plugin's iOS setup: the registrant callback (so
    // plugins are available inside the background isolate) and the periodic
    // task's identifier must both be registered here, before the app
    // finishes launching — registering later, or only from Dart, does
    // nothing on iOS. The identifier string must match
    // BGTaskSchedulerPermittedIdentifiers in Info.plist and kLocationTaskId
    // in location_task.dart exactly.
    SwiftWorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    if #available(iOS 13.0, *) {
      // frequency here is advisory only (iOS schedules opportunistically
      // based on app-usage patterns, not a guaranteed 24h clock) — the
      // authoritative `frequency: Duration(hours: 24)` lives in
      // LocationBackgroundTask.schedule() on the Android side.
      SwiftWorkmanagerPlugin.registerPeriodicTask(
        withIdentifier: "com.enervara.enervara.locationRefresh",
        frequency: NSNumber(value: 24 * 60 * 60)
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
