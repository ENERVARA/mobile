/// App-wide configuration. The API base URL can be overridden at build time
/// with `--dart-define=API_URL=...`; it defaults to the Railway **production**
/// (master) backend.
class AppConfig {
  AppConfig._();

  static const appName = 'Enervara';
  static const tagline = 'Hospital-grade care. Zero waiting rooms.';
  static const version = '1.0.0';

  /// Prod: `enervarabackend` (no hyphen). Staging: `enervara-backend` (hyphen).
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://enervarabackend.up.railway.app/api',
  );

  /// The deployed web app's origin — used only to build the public SOAP
  /// share link (`<webAppUrl>/share/soap/:token>`), which is rendered by the
  /// web app's `SoapSharePage`, not by this app. Prod: `app.enervara.com`.
  /// Staging: `enervara-app` (hyphen, on Railway).
  static const webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://app.enervara.com',
  );

  static const emergencyNumber = '112';
  static const ambulanceNumber = '102';

  // Upload constraints (mirrors src/constants/config.ts).
  static const maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const acceptedMimeTypes = <String>[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'application/dicom',
  ];
  static const acceptedExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'dcm',
  ];
}
