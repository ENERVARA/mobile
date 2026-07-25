/// Theme-aware speciality hero images (bundled from the web app's `/public/img`).
/// `<base>_W.jpg` for light, `<base>_D.jpg` for dark.
const _bases = <String, String>{
  'general-medicine': 'general',
  'gastroenterology': 'gastroen',
  'cardiology': 'cardiology',
  'dermatology': 'dermatology',
  'ent': 'ent',
  'pulmonology': 'pulmon',
  'orthopedics': 'Orthopedics',
  'neurology': 'Neurology',
  'mental-health': 'mental',
  'emotional-health': 'emotional',
  'pediatrics': 'pediatrics',
};

/// Asset path for a speciality's hero image, or null if none exists.
String? specialityImageAsset(String slug, {required bool isDark}) {
  final base = _bases[slug];
  if (base == null) return null;
  final suffix = isDark ? 'D' : 'W';
  return 'assets/images/specialities/${base}_$suffix.jpg';
}
