import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

/// A Google sign-in that failed for a reason the user should see. Thrown
/// instead of letting the raw platform exception escape, because these never
/// pass through the API client and so are never toasted by it — the calling
/// page has to surface them itself.
class GoogleAuthFailure implements Exception {
  final String message;
  const GoogleAuthFailure(this.message);
  @override
  String toString() => message;
}

/// Runs the native Google account picker and exchanges the result for a
/// Firebase session, producing the Firebase ID token our backend's
/// `POST /auth/google` expects (it verifies via the Firebase Admin SDK — see
/// `verifyIdToken` in `backend/src/controllers/auth.controller.ts`, NOT the
/// raw Google ID token, hence the extra `signInWithCredential` hop).
class GoogleAuthService {
  GoogleAuthService._();
  static final instance = GoogleAuthService._();

  // The "Web client" OAuth client Firebase auto-provisions for this project
  // (the client_type: 3 entry in android/app/google-services.json). Passing
  // this as serverClientId is what makes the resulting Google ID token's
  // audience acceptable to Firebase across both Android and iOS.
  static const _serverClientId =
      '585113598278-uvn4vmcreqvtrtlina9v27i73lsf0c2r.apps.googleusercontent.com';

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Shows the account picker, signs into Firebase with the result, and
  /// returns a fresh Firebase ID token. Returns null **only** if the user
  /// canceled — callers must treat that as a silent no-op (and must NOT report
  /// success). Every other failure throws [GoogleAuthFailure].
  Future<String?> signInAndGetIdToken() async {
    try {
      await _ensureInitialized();
    } on GoogleSignInException catch (e) {
      throw GoogleAuthFailure(_describe(e));
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleAuthFailure(_describe(e));
    }

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null) {
      throw const GoogleAuthFailure(
        'Google did not return an ID token. This build\'s signing certificate '
        'is most likely not registered in Firebase.',
      );
    }

    final credential = fb.GoogleAuthProvider.credential(idToken: googleIdToken);
    try {
      final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw const GoogleAuthFailure('Could not obtain a Firebase session');
      }
      return firebaseIdToken;
    } on fb.FirebaseAuthException catch (e) {
      throw GoogleAuthFailure(e.message ?? 'Firebase rejected the Google sign-in (${e.code})');
    }
  }

  /// Turns a platform sign-in failure into something actionable. The
  /// configuration codes almost always mean the running build's signing
  /// certificate SHA-1 isn't registered on the Firebase Android app — note
  /// that a Play Store build is re-signed by **Play App Signing**, so its
  /// certificate differs from both the debug and the upload keystore.
  static String _describe(GoogleSignInException e) {
    final detail = (e.description ?? '').trim();
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured for this build. Register this '
            "app's signing certificate SHA-1 in Firebase, then try again."
            '${detail.isEmpty ? '' : ' ($detail)'}';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No Google account is available on this device. Add a Google '
            'account in system settings, then try again.'
            '${detail.isEmpty ? '' : ' ($detail)'}';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Please try again.'
            '${detail.isEmpty ? '' : ' ($detail)'}';
      default:
        return detail.isEmpty
            ? 'Google sign-in failed (${e.code.name}). Please try again.'
            : 'Google sign-in failed: $detail';
    }
  }

  /// Best-effort sign-out of both SDKs — called on app logout so the account
  /// picker doesn't silently re-auth the same Google account next time.
  Future<void> signOut() async {
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {/* not signed into Firebase — fine */}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {/* not initialized/signed in — fine */}
  }
}
