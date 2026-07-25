import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

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
  /// returns a fresh Firebase ID token. Returns null if the user canceled —
  /// callers should treat that as a silent no-op, not an error.
  Future<String?> signInAndGetIdToken() async {
    await _ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null) {
      throw Exception('Google did not return an ID token');
    }

    final credential = fb.GoogleAuthProvider.credential(idToken: googleIdToken);
    final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCredential.user?.getIdToken();
    if (firebaseIdToken == null) {
      throw Exception('Could not obtain a Firebase session');
    }
    return firebaseIdToken;
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
