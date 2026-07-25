import '../../core/api/api_client.dart';

/// FCM device-token registration (`/api/notifications/*`). Mirrors the
/// backend's `notifications.routes.ts` — separate from the admin-only
/// send/schedule surface.
class NotificationsService {
  const NotificationsService();

  Future<void> registerToken(String token, {String platform = 'android'}) async {
    await dio.post('/notifications/register-token', data: {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> unregisterToken(String token) async {
    await dio.post('/notifications/unregister-token', data: {'token': token});
  }
}
