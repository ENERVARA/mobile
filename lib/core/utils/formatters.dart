import 'package:intl/intl.dart';

/// Formatting helpers shared across screens.
class Formatters {
  Formatters._();

  /// Human file size, e.g. `1.2 MB` / `840 KB`.
  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final str = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(size >= 10 ? 0 : 1);
    return '$str ${units[unit]}';
  }

  /// Relative "time ago" — used for conversation + report timestamps.
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Clock time for a chat bubble, e.g. `10:24 PM`.
  static String messageTime(DateTime date) => DateFormat('h:mm a').format(date);

  /// Medium date, e.g. `Jul 15, 2026`.
  static String dateMedium(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  /// Parse an ISO string safely to local time.
  static DateTime? tryParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  /// Age in whole years from an ISO date-of-birth (or null).
  static int? ageFromDob(String? dob) {
    final d = tryParse(dob);
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age < 0 ? null : age;
  }
}

/// BMI result, mirroring `src/utils/bmi.ts`.
class BmiResult {
  final double value;
  final String category;
  const BmiResult(this.value, this.category);
}

BmiResult? computeBmi({double? heightCm, double? weightKg}) {
  if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
    return null;
  }
  final m = heightCm / 100.0;
  final bmi = weightKg / (m * m);
  final rounded = double.parse(bmi.toStringAsFixed(1));
  String category;
  if (bmi < 18.5) {
    category = 'Underweight';
  } else if (bmi < 25) {
    category = 'Healthy';
  } else if (bmi < 30) {
    category = 'Overweight';
  } else {
    category = 'Obese';
  }
  return BmiResult(rounded, category);
}
