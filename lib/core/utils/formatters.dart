import 'package:intl/intl.dart';

/// Formatting helpers shared across screens.
class Formatters {
  Formatters._();

  /// Human file size, e.g. `1.2 MB` / `840 KB`. Mirrors `src/utils/fileSize.ts`
  /// (one decimal from KB upwards).
  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(unit > 0 ? 1 : 0)} ${units[unit]}';
  }

  /// Full weekday date, e.g. `Sunday, July 19, 2026` (`formatDateFull`).
  static String dateFull(DateTime date) => DateFormat('EEEE, MMMM d, yyyy').format(date);

  /// Date, plus a clock time when the underlying value actually carries one
  /// (`formatDateTime`). A document's printed date parses to local midnight and
  /// is shown as a bare date rather than a fabricated "12:00 AM".
  static String dateTime(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0 || date.second != 0;
    return hasTime
        ? DateFormat('MMM d, yyyy · h:mm a').format(date)
        : DateFormat('MMM d, yyyy').format(date);
  }

  /// `formatDateTime` for an ISO string; empty when it can't be parsed.
  static String dateTimeIso(String? iso) {
    final d = tryParse(iso);
    return d == null ? '' : dateTime(d);
  }

  /// `September 2026` (`formatMonthYear`) — timeline month headers.
  static String monthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);

  /// `10 Sep`, or `10 Sep 2026` with the year (`formatEventDate`, en-GB).
  static String eventDate(String? iso, {bool withYear = false}) {
    final d = tryParse(iso);
    if (d == null) return '';
    return DateFormat(withYear ? 'dd MMM yyyy' : 'dd MMM').format(d);
  }

  /// `10 Sep 2026` (en-GB `{ day: 'numeric', month: 'short', year: 'numeric' }`).
  static String dayMonthYear(DateTime date) => DateFormat('d MMM yyyy').format(date);

  /// `Mon, Oct 5, 10:30 AM` — the short appointment stamp (`toLocaleString` with
  /// weekday/day/month/hour/minute, en-US).
  static String appointmentShort(DateTime date) =>
      DateFormat('EEE, MMM d, hh:mm a').format(date);

  /// `Monday, October 5 at 10:30 AM` — the long appointment stamp.
  static String appointmentLong(DateTime date) =>
      DateFormat("EEEE, MMMM d 'at' hh:mm a").format(date);

  /// `Mon, Oct 5` — a slot-picker day heading.
  static String dayShort(DateTime date) => DateFormat('EEE, MMM d').format(date);

  /// `10:30 AM` — a slot time chip.
  static String timeHm(DateTime date) => DateFormat('hh:mm a').format(date);

  /// `Oct 5, 10:30 AM` — appointment history timestamps.
  static String dayMonthTime(DateTime date) => DateFormat('MMM d, hh:mm a').format(date);

  /// Initials for an avatar (`initialsOf`).
  static String initialsOf(String? first, String? last) {
    final a = (first ?? '').trim();
    final b = (last ?? '').trim();
    final both = ((a.isNotEmpty ? a[0] : '') + (b.isNotEmpty ? b[0] : '')).toUpperCase();
    if (both.isNotEmpty) return both;
    final f = first ?? '';
    return f.isNotEmpty ? f[0].toUpperCase() : 'U';
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
