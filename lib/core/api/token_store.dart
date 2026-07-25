import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the 7-day access JWT (matches the web app's `localStorage.token`),
/// with an in-memory cache so the Dio interceptor + SSE client can read it
/// synchronously on every request.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _key = 'enervara_token';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String? _cached;
  String? get token => _cached;
  bool get hasToken => _cached != null && _cached!.isNotEmpty;

  /// Load the persisted token into the cache at boot.
  Future<String?> load() async {
    _cached = await _secure.read(key: _key);
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    await _secure.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _secure.delete(key: _key);
  }
}
