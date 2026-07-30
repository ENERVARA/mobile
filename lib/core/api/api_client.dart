import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../ui/app_messenger.dart';
import 'token_store.dart';

/// A parsed error envelope: `{code, message, request_id, details}`.
///
/// `code` is the stable machine-readable discriminator; `requestId` is what
/// correlates a failure to backend logs, so it's worth quoting in a bug report.
class ApiError implements Exception {
  final String code;
  final String message;
  final String requestId;
  final int? status;

  const ApiError({
    required this.code,
    required this.message,
    this.requestId = '',
    this.status,
  });

  /// Transient upstream trouble — safe to retry with a back-off.
  bool get isRetryable => code == 'UPSTREAM_UNAVAILABLE' || code == 'RATE_LIMITED';

  factory ApiError.from(dynamic data, {int? status, String? headerRequestId}) {
    final map = data is Map ? data : const {};
    final code = map['code']?.toString();
    return ApiError(
      code: code ?? _codeForStatus(status),
      message: map['message']?.toString() ?? _messageForStatus(status),
      requestId: map['request_id']?.toString() ?? headerRequestId ?? '',
      status: status,
    );
  }

  static String _codeForStatus(int? status) {
    switch (status) {
      case 400:
        return 'INVALID_INPUT';
      case 401:
        return 'UNAUTHORIZED';
      case 429:
        return 'RATE_LIMITED';
      case 502:
      case 503:
        return 'UPSTREAM_UNAVAILABLE';
      default:
        return 'INTERNAL_ERROR';
    }
  }

  static String _messageForStatus(int? status) {
    switch (status) {
      case 429:
        return 'Nova is busy right now. Give it a moment.';
      case 502:
      case 503:
        return 'Nova is temporarily unavailable. Try again shortly.';
      default:
        return 'Something went wrong';
    }
  }

  @override
  String toString() => '$code: $message';
}

/// Central Dio instance. Mirrors the web `src/services/api.ts`:
/// - attaches `Authorization: Bearer <token>` on every request,
/// - on 401 wipes the token and fires [onUnauthorized] (router bounces to login),
/// - retries transient upstream failures with an exponential back-off,
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
        onResponse: (response, handler) async {
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
                error: const ApiError(code: 'UNAUTHORIZED', message: 'Unauthorized', status: 401),
              ),
            );
            return;
          }
          if (status >= 400) {
            final apiError = ApiError.from(
              response.data,
              status: status,
              headerRequestId: response.headers.value('x-request-id'),
            );
            if (apiError.isRetryable && _canRetry(response.requestOptions)) {
              final retried = await _retry(response.requestOptions);
              if (retried != null) {
                handler.resolve(retried);
                return;
              }
            }
            AppMessenger.error(apiError.message);
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: apiError,
              ),
            );
            return;
          }
          handler.next(response);
        },
        onError: (err, handler) async {
          if (err.type == DioExceptionType.cancel) {
            handler.next(err);
            return;
          }
          final transport = _isTransport(err);
          final apiError = transport
              ? const ApiError(
                  code: 'NETWORK_ERROR',
                  message: 'Network problem. Check your connection.',
                )
              : ApiError.from(
                  err.response?.data,
                  status: err.response?.statusCode,
                  headerRequestId: err.response?.headers.value('x-request-id'),
                );
          // Network / timeout / 5xx — all transient enough to be worth a retry.
          if ((apiError.isRetryable || transport) && _canRetry(err.requestOptions)) {
            final retried = await _retry(err.requestOptions);
            if (retried != null) {
              handler.resolve(retried);
              return;
            }
          }
          AppMessenger.error(apiError.message);
          handler.next(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: err.type,
              error: apiError,
            ),
          );
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

  static bool _isTransport(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.connectionError;

  /// A request is only replayable if its body can be sent twice and its
  /// response isn't a live stream. `FormData` is a consumable stream, so an
  /// image upload is never auto-retried — re-sending it would send nothing.
  static bool _canRetry(RequestOptions options) {
    if (options.data is FormData) return false;
    if (options.responseType == ResponseType.stream) return false;
    if (options.cancelToken?.isCancelled ?? false) return false;
    return (options.extra[_attemptKey] as int? ?? 0) < _maxRetries;
  }

  static const _attemptKey = '_retryAttempt';

  /// Two retries, so three attempts total.
  static const _maxRetries = 2;

  /// Exponential back-off: 1 s then 2 s (capped at 8 s).
  Future<Response<dynamic>?> _retry(RequestOptions options) async {
    final attempt = (options.extra[_attemptKey] as int? ?? 0) + 1;
    final delayMs = (1000 * (1 << (attempt - 1))).clamp(1000, 8000);
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (options.cancelToken?.isCancelled ?? false) return null;
    try {
      return await dio.fetch<dynamic>(
        options..extra = {...options.extra, _attemptKey: attempt},
      );
    } catch (_) {
      // Fall through to the normal error path with the original failure.
      return null;
    }
  }
}

/// Shorthand used by service files.
Dio get dio => ApiClient.instance.dio;
