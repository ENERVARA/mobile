import '../../core/api/api_client.dart';
import '../models/user.dart';

/// Auth endpoints (`/api/auth/*`). Mirrors the flows in `authStore.ts`.
/// Every issuance point returns `{ accessToken }`.
class AuthService {
  const AuthService();

  Future<String> login(String identifier, String password) async {
    final res = await dio.post('/auth/login', data: {
      'identifier': identifier,
      'password': password,
    });
    final token = res.data?['accessToken'] as String?;
    if (token == null) throw Exception(res.data?['message'] ?? 'Login failed');
    return token;
  }

  /// Creates an unverified user + emails a magic verification link.
  Future<void> requestSignup({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await dio.post('/auth/signup', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone.replaceAll(RegExp(r'\D'), ''),
      'password': password,
    });
  }

  Future<String> verifySignup(String token) async {
    final res = await dio.post('/auth/verify-signup', data: {'token': token});
    final t = res.data?['accessToken'] as String?;
    if (t == null) throw Exception(res.data?['message'] ?? 'Verification failed');
    return t;
  }

  Future<void> forgotPassword(String email) async {
    await dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<String> resetPassword(String token, String newPassword) async {
    final res = await dio.post('/auth/reset-password', data: {
      'token': token,
      'newPassword': newPassword,
    });
    final t = res.data?['accessToken'] as String?;
    if (t == null) throw Exception(res.data?['message'] ?? 'Reset failed');
    return t;
  }

  /// Exchanges a Firebase Google ID token for our access token.
  Future<({String token, bool isNewUser})> google(String idToken) async {
    final res = await dio.post('/auth/google', data: {'token': idToken});
    final t = res.data?['accessToken'] as String?;
    if (t == null) throw Exception(res.data?['message'] ?? 'Google sign-in failed');
    return (token: t, isNewUser: res.data?['isNewUser'] == true);
  }

  Future<User> fetchMe() async {
    final res = await dio.get('/auth/me');
    return User.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<User> updateMe(Map<String, dynamic> patch) async {
    final res = await dio.patch('/auth/me', data: patch);
    return User.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<User> completeOnboarding() async {
    final res = await dio.post('/auth/complete-onboarding');
    return User.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteAccount() async {
    await dio.delete('/auth/me');
  }
}
