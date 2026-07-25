import 'package:dio/dio.dart' as dio_pkg;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/services/notifications_service.dart';
import '../../firebase_options.dart';

/// The single Android channel every push lands in — id matches the backend's
/// `androidChannelId` default ("enervara_default", see admin.controller.ts)
/// and the AndroidManifest `default_notification_channel_id` meta-data.
const _kDefaultChannel = AndroidNotificationChannel(
  'enervara_default',
  'Enervara notifications',
  description: 'Care reminders, updates and announcements from Enervara.',
  importance: Importance.high,
);

/// Runs in a separate background isolate — Firebase must be re-initialised
/// here. Kept top-level + entry-point-annotated per firebase_messaging's
/// requirements; intentionally does nothing beyond that: Android/iOS render
/// the system tray entry for background/terminated pushes on their own.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Wires up Firebase Cloud Messaging: permission request, device-token
/// registration with the backend, foreground display (FCM does this for you
/// automatically in background/terminated state, but not in foreground), and
/// tap-to-navigate via a `route` key in the notification's `data` payload
/// (set as a "Custom data" field when composing in the admin portal).
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _service = const NotificationsService();

  /// Set by the app shell once the router exists; called with `data['route']`
  /// whenever the user taps a notification.
  void Function(String route)? onNotificationTap;

  bool _initialized = false;

  /// Sets up listeners and local-notification channels. Safe to call once at
  /// app boot, before the user is authenticated — token registration itself
  /// happens separately via [registerToken] once logged in.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) onNotificationTap?.call(route);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kDefaultChannel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // iOS: show the banner even while the app is in the foreground.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground: FCM delivers the message but does NOT auto-display it —
    // that's our job, via the local-notifications plugin.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was backgrounded (not terminated) and the user tapped the tray entry.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App was fully terminated and launched BY tapping a notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // A refreshed token needs re-registering if the user is signed in;
    // no-ops harmlessly (401) if they aren't — acceptable, next login re-syncs.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _service.registerToken(token, platform: _platform()).catchError((_) {});
    });
  }

  /// Call once the user is authenticated (auth_provider does this after
  /// hydrating the session) so the backend can target this device.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _service.registerToken(token, platform: _platform());
    } catch (e) {
      debugPrint('PushNotificationService.registerToken failed: $e');
    }
  }

  /// Call on logout, while the auth token is still valid (before it's cleared).
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _service.unregisterToken(token);
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken failed: $e');
    }
  }

  void _handleTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.isNotEmpty) onNotificationTap?.call(route);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // The admin's chosen accent color/image travel in the native
    // notification.android payload (see backend's fcm.ts baseMessage), NOT
    // the `data` bag — that's why these read from `notification.android`.
    final accent = _parseColor(notification.android?.color);
    final imageUrl = notification.android?.imageUrl;
    final bigPicture = imageUrl != null ? await _downloadBytes(imageUrl) : null;

    await _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kDefaultChannel.id,
          _kDefaultChannel.name,
          channelDescription: _kDefaultChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: accent,
          styleInformation: bigPicture != null
              ? BigPictureStyleInformation(ByteArrayAndroidBitmap(bigPicture))
              : null,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String?,
    );
  }

  String _platform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  Color? _parseColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final res = await dio_pkg.Dio().get<List<int>>(
        url,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );
      final data = res.data;
      return data != null ? Uint8List.fromList(data) : null;
    } catch (_) {
      return null; // Foreground banner just shows without the image.
    }
  }
}
