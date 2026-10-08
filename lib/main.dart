import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background/location_geofence.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options.dart';

/// A widget failing to build (anywhere in the app) shows this instead of
/// Flutter's default error box, which in profile/release mode is a bare grey
/// rectangle with no text — against a dark theme that reads as an empty black
/// screen, with no hint anything went wrong. This never hides a bug, it just
/// makes it visible instead of silent.
Widget _buildErrorFallback(FlutterErrorDetails details) {
  return Material(
    color: const Color(0xFF141416),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFF26440), size: 36),
              const SizedBox(height: 12),
              const Text(
                "Something didn't load correctly",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = _buildErrorFallback;

  try {
    // Run initializations with timeout to avoid hanging indefinitely on cold start
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      LocationGeofenceManager.initialize(),
    ]).timeout(const Duration(seconds: 10));

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.init();

    runApp(const ProviderScope(child: EnervaraApp()));
  } catch (e, stacktrace) {
    debugPrint("ENERVARA ERROR: $e");
    debugPrint(stacktrace.toString());

    // Failsafe: Launch an error screen if initialization completely fails
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "App failed to start. Please check your internet connection and try again.\n\nError: $e",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
