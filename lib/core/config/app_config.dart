/// App-wide configuration. The API base URL can be overridden at build time
/// with `--dart-define=API_URL=...`; it defaults to the Railway **staging**
/// backend (matches the `staging` branch this app was ported from).
class AppConfig {
  AppConfig._();

  static const appName = 'Enervara';
  static const tagline = 'Hospital-grade care. Zero waiting rooms.';
  static const version = '1.0.0';

  /// Staging: `enervara-backend` (hyphen). Prod: `enervarabackend` (no hyphen).
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://enervara-backend.up.railway.app/api',
  );

  static const emergencyNumber = '112';

  // Upload constraints (mirrors src/constants/config.ts).
  static const maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const acceptedMimeTypes = <String>[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'application/dicom',
  ];
  static const acceptedExtensions = <String>['pdf', 'jpg', 'jpeg', 'png', 'dcm'];

  /// Chat image uploads are narrower than report uploads: the service accepts
  /// `image/png` and `image/jpeg` only, caps at 10 MB, and sniffs the bytes —
  /// a mislabelled file is rejected server-side, so filter before sending.
  static const chatImageMimeTypes = <String>['image/png', 'image/jpeg'];
  static const chatImageExtensions = <String>['png', 'jpg', 'jpeg'];
}
