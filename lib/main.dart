import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background/location_geofence.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
