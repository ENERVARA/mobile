import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/token_store.dart';
import '../core/auth/google_auth_service.dart';
import '../core/background/location_geofence.dart';
import '../core/notifications/push_notification_service.dart';
import '../data/models/user.dart';
import '../data/services/auth_service.dart';
import '../data/services/location_service.dart';
import 'onboarding_provider.dart';

final authServiceProvider = Provider((ref) => const AuthService());

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isHydrated;
  final bool isLoading;
  final bool isFreshLogin;
  final String? error;
  final String? pendingSignupEmail;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isHydrated = false,
    this.isLoading = false,
    this.isFreshLogin = false,
    this.error,
    this.pendingSignupEmail,
  });

  AuthState copyWith({
    User? user,
    bool clearUser = false,
    bool? isAuthenticated,
    bool? isHydrated,
    bool? isLoading,
    bool? isFreshLogin,
    String? error,
    bool clearError = false,
    String? pendingSignupEmail,
    bool clearPending = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isHydrated: isHydrated ?? this.isHydrated,
      isLoading: isLoading ?? this.isLoading,
      isFreshLogin: isFreshLogin ?? this.isFreshLogin,
      error: clearError ? null : (error ?? this.error),
      pendingSignupEmail: clearPending
          ? null
          : (pendingSignupEmail ?? this.pendingSignupEmail),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;
  AuthService get _service => _ref.read(authServiceProvider);

  /// Boot flow: load persisted token, hydrate the user, mark hydrated.
  Future<void> bootstrap() async {
    await TokenStore.instance.load();
    if (TokenStore.instance.hasToken) {
      await _hydrateUser();
    }
    state = state.copyWith(isHydrated: true);
  }

  Future<void> _hydrateUser({bool isFreshLogin = false}) async {
    try {
      final user = await _service.fetchMe();
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isFreshLogin: isFreshLogin,
      );
      // Fire-and-forget onboarding load (mirrors authStore.fetchMe).
      unawaited(_ref.read(onboardingProvider.notifier).load());
      // Register this device for push notifications now that we have a
      // valid session; no-ops quietly if Firebase isn't configured yet.
      unawaited(PushNotificationService.instance.registerToken());
      // Re-arm the location geofence if this device was already on
      // "continuous" from a previous login — safe/idempotent to call on
      // every boot. Does NOT re-prompt; the access sheet is shown
      // elsewhere, exactly once ever, gated by LocationService.hasDecided().
      unawaited(LocationService.instance.rearmIfNeeded());
    } catch (_) {
      await TokenStore.instance.clear();
      state = state.copyWith(clearUser: true, isAuthenticated: false);
    }
  }

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _service.login(identifier, password);
      await TokenStore.instance.save(token);
      // _hydrateUser sets isAuthenticated + user together in one atomic
      // update — setting isAuthenticated here first would let the router
      // see "authenticated, user still null" and briefly route as if the
      // account were brand-new (flashing the onboarding screen).
      await _hydrateUser(isFreshLogin: true);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Google sign-in/up (same endpoint handles both — the backend creates the
  /// account on first sign-in). Returns silently if the user cancels the
  /// native account picker; that's not an error worth surfacing.
  /// Returns true only when a session was actually established. False means
  /// the user dismissed the account picker — callers must stay silent in that
  /// case rather than reporting a successful sign-in.
  Future<bool> googleSignIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final idToken = await GoogleAuthService.instance.signInAndGetIdToken();
      if (idToken == null) return false; // user canceled the picker
      final result = await _service.google(idToken);
      await TokenStore.instance.save(result.token);
      await _hydrateUser(isFreshLogin: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> requestSignup({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.requestSignup(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
      );
      state = state.copyWith(pendingSignupEmail: email);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> verifySignup(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final t = await _service.verifySignup(token);
      await TokenStore.instance.save(t);
      state = state.copyWith(clearPending: true);
      await _hydrateUser(isFreshLogin: true);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.forgotPassword(email);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final t = await _service.resetPassword(token, newPassword);
      await TokenStore.instance.save(t);
      await _hydrateUser();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateMe(Map<String, dynamic> patch) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.updateMe(patch);
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void consumeFreshLogin() {
    if (state.isFreshLogin) {
      state = state.copyWith(isFreshLogin: false);
    }
  }

  Future<void> completeOnboarding() async {
    final user = await _service.completeOnboarding();
    state = state.copyWith(user: user);
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.deleteAccount();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> logout() async {
    // Must run before the token is cleared — unregister-token is authenticated.
    await PushNotificationService.instance.unregisterToken();
    await GoogleAuthService.instance.signOut();
    await TokenStore.instance.clear();
    _ref.read(onboardingProvider.notifier).clear();
    // Stop background tracking for this signed-out session. Deliberately
    // leaves the chosen access mode + last snapshot in local storage —
    // re-logging in on the same device re-arms via rearmIfNeeded() above
    // without re-showing the access sheet.
    unawaited(LocationGeofenceManager.cancel());
    state = const AuthState(isHydrated: true);
  }

  /// Called by the API client on a 401 for an authenticated request.
  void forceLogout() {
    TokenStore.instance.clear();
    _ref.read(onboardingProvider.notifier).clear();
    unawaited(LocationGeofenceManager.cancel());
    state = const AuthState(isHydrated: true);
  }

  static String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}
