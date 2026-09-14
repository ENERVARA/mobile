import Flutter
import UIKit
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Location check-in's "continuous" access mode (LocationService /
    // lib/core/background/location_geofence.dart) — native_geofence needs
    // this registrant callback so plugins are available inside the
    // background isolate a geofence event wakes up. Per the plugin's iOS
    // setup docs, this must be registered before the app finishes launching.
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
