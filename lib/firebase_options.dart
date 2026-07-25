// File generated for the "Enervara" Firebase project (health-81575).
//
// ⚠️  PLACEHOLDER — apiKey/appId values below are NOT real yet. See
// FIREBASE_SETUP.md at the repo root of mobile_app/ for exactly how to fill
// them in (two options: paste config from the Firebase console, or run
// `flutterfire configure` yourself, which overwrites this file with the
// real thing in the same shape).
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Usage:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Web ── (Firebase console → Project settings → General → Your apps →
  // Web app → the `firebaseConfig` object shown there maps 1:1 to these fields)

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDUQZMRNsZz6kJq8SiN9nz1NXeQNrxwCh0',
    appId: '1:585113598278:web:346f863d387e56aa964d47',
    messagingSenderId: '585113598278',
    projectId: 'health-81575',
    authDomain: 'health-81575.firebaseapp.com',
    storageBucket: 'health-81575.firebasestorage.app',
    measurementId: 'G-WZYC1QHNVG',
  );
  // ── Android ── (from google-services.json, once added at
  // android/app/google-services.json — see FIREBASE_SETUP.md)

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGTRcaj2WzMy3U1xIbhWSt_lZ5stHQ4Rg',
    appId: '1:585113598278:android:3b811048248f103e964d47',
    messagingSenderId: '585113598278',
    projectId: 'health-81575',
    storageBucket: 'health-81575.firebasestorage.app',
  );
  // ── iOS ── (from GoogleService-Info.plist, once added at
  // ios/Runner/GoogleService-Info.plist — see FIREBASE_SETUP.md)

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBh9rqs0XC7dKiHmxrfrW7lsxSRC3T0rfA',
    appId: '1:585113598278:ios:916d18277939f4a8964d47',
    messagingSenderId: '585113598278',
    projectId: 'health-81575',
    storageBucket: 'health-81575.firebasestorage.app',
    iosClientId: '585113598278-origfmhbm0kqvegfmkgotmvhlsfapivn.apps.googleusercontent.com',
    iosBundleId: 'com.enervara.enervara',
  );
}
