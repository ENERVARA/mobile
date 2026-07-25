import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.init();
  } catch (e) {
    // firebase_options.dart still has placeholder keys until FIREBASE_SETUP.md
    // is completed — push notifications simply stay off, nothing else breaks.
    debugPrint('Firebase/push-notifications unavailable: $e');
  }

  runApp(const ProviderScope(child: EnervaraApp()));
}
