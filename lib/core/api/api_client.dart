import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../ui/app_messenger.dart';
import 'token_store.dart';

/// Central Dio instance. Mirrors the web `src/services/api.ts`:
/// - attaches `Authorization: Bearer <token>` on every request,
/// - on 401 wipes the token and fires [onUnauthorized] (router bounces to login),
/// - auto-toasts other 4xx/5xx errors via [AppMessenger].
class ApiClient {
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        // We inspect statusCode ourselves so error envelopes are readable.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = TokenStore.instance.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final status = response.statusCode ?? 0;
          // A 401 on a pre-session auth call (login/signup/reset/google) is a
          // bad-credentials error, NOT an expired session — don't wipe/redirect.
          final path = response.requestOptions.path;
          final isPreSession = _preSessionPaths.any(path.contains);
          if (status == 401 && !isPreSession) {
            _handleUnauthorized(response.data);
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: 'Unauthorized',
              ),
            );
            return;
          }
          if (status >= 400) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: _messageOf(response.data),
              ),
            );
            return;
          }
          handler.next(response);
        },
        onError: (err, handler) {
          // Toasting happens here only, so a failed request is never shown
          // twice. Silent on purpose for:
          // - cancellations (the request was intentionally aborted),
          // - 401s (already handled above — session wipe/redirect, no toast
          //   unless it's the account-deletion-pending case),
          // - responseless network/timeout errors (no backend message to
          //   show, and these fire routinely on a cold app launch before
          //   the network/backend is ready — mirrors the dashboard, which
          //   stays silent on connectivity errors too).
          final status = err.response?.statusCode;
          if (err.type != DioExceptionType.cancel && status != null && status != 401) {
            final msg = _messageOf(err.response?.data) ?? 'Something went wrong';
            AppMessenger.error(msg);
          }
          handler.next(err);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio dio;

  static const _preSessionPaths = [
    '/auth/login',
    '/auth/signup',
    '/auth/verify-signup',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/auth/google',
  ];

  /// Set by the app root — clears auth state so go_router redirects to /login.
  void Function()? onUnauthorized;

  void _handleUnauthorized(dynamic data) {
    final code = (data is Map) ? data['code'] as String? : null;
    if (code == 'ACCOUNT_DELETION_PENDING') {
      AppMessenger.error('This account is scheduled for deletion. Log in again to cancel.');
    }
    TokenStore.instance.clear();
    onUnauthorized?.call();
  }

  static String? _messageOf(dynamic data) {
    if (data is Map && data['message'] is String) return data['message'] as String;
    return null;
  }
}

/// Shorthand used by service files.
Dio get dio => ApiClient.instance.dio;
