import '../../data/models/lab_report.dart';

/// Deterministic lab trends. Ported from `features/healthRecords/labTrends.ts`.
///
/// Numbers, units, dates and comparability are decided here, in plain code —
/// never by a model. Two readings are only ever placed on the same trend when
/// they name the same test (after mapping lab-specific spellings to one
/// canonical parameter) AND carry the same unit. Nothing is converted between
/// units: a mismatch is a separate, shorter trend rather than a guessed one.

/// Lab-specific spellings of the same test, keyed by the canonical name.
const _canonicalAliases = <String, List<String>>{
  'Hemoglobin': ['hb', 'hgb', 'haemoglobin', 'hemoglobin'],
  'HbA1c': [
    'hba1c',
    'a1c',
    'glycated haemoglobin',
    'glycated hemoglobin',
    'glycosylated hb',
    'glycosylated haemoglobin',
    'glycosylated hemoglobin',
  ],
  'Fasting Glucose': [
    'fasting glucose',
    'glucose fasting',
    'fasting blood sugar',
    'fbs',
    'fasting plasma glucose',
    'fpg',
  ],
  'Total Cholesterol': ['total cholesterol', 'cholesterol total', 'serum cholesterol'],
  'LDL Cholesterol': ['ldl', 'ldl c', 'ldl cholesterol', 'cholesterol ldl'],
  'HDL Cholesterol': ['hdl', 'hdl c', 'hdl cholesterol', 'cholesterol hdl'],
  'Triglycerides': ['triglycerides', 'triglyceride', 'tg', 'serum triglycerides'],
  'Platelet Count': ['platelets', 'platelet count', 'plt'],
  'WBC Count': [
    'wbc',
    'wbc count',
    'total wbc count',
    'tlc',
    'total leucocyte count',
    'total leukocyte count',
    'white blood cell count',
  ],
  'RBC Count': ['rbc', 'rbc count', 'total rbc count', 'red blood cell count'],
  'Creatinine': ['creatinine', 'serum creatinine', 's creatinine'],
  'TSH': ['tsh', 'thyroid stimulating hormone'],
};

String _normalize(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

final Map<String, String> _aliasIndex = {
  for (final e in _canonicalAliases.entries)
    for (final alias in e.value) _normalize(alias): e.key,
};

class CanonicalParameter {
  final String key;
  final String name;
  const CanonicalParameter(this.key, this.name);
}

/// Maps a printed test name to its canonical identity. Unknown names keep their
/// own spelling as their identity, so they still trend against themselves.
CanonicalParameter canonicalParameter(String testName) {
  final normalized = _normalize(testName);
  final canonical = _aliasIndex[normalized];
  if (canonical != null) return CanonicalParameter(_normalize(canonical), canonical);
  return CanonicalParameter(normalized, testName.trim());
}

String _normalizeUnit(String? unit) =>
    (unit ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

class TrendPoint {
  final String date;
  final double value;
  final String status;
  final double? referenceLow;
  final double? referenceHigh;
  final String reportId;
  const TrendPoint({
    required this.date,
    required this.value,
    required this.status,
    this.referenceLow,
    this.referenceHigh,
    required this.reportId,
  });
}

class LabTrend {
  /// `${parameterKey}|${unit}` — unique per comparable series.
  final String id;
  final String parameterKey;
  final String name;
  final String? unit;

  /// Oldest first.
  final List<TrendPoint> points;
  final String direction; // increasing | decreasing | stable
  final TrendPoint latest;
  const LabTrend({
    required this.id,
    required this.parameterKey,
    required this.name,
    required this.unit,
    required this.points,
    required this.direction,
    required this.latest,
  });
}

/// A change smaller than this share of the first value reads as stable.
const _stableThreshold = 0.02;

String directionOf(List<TrendPoint> points) {
  final first = points.first.value;
  final last = points.last.value;
  final change = last - first;
  if (first == 0) return change == 0 ? 'stable' : (change > 0 ? 'increasing' : 'decreasing');
  if ((change / first).abs() < _stableThreshold) return 'stable';
  return change > 0 ? 'increasing' : 'decreasing';
}

/// Builds every comparable series from saved reports. Only verified (SAVED)
/// reports count — extracted values the user has not reviewed are not history.
/// A series becomes a trend only once it has two or more readings.
List<LabTrend> buildLabTrends(List<LabReport> reports) {
  final series = <String, ({String name, String? unit, List<TrendPoint> points})>{};

  for (final report in reports) {
    if (report.status != 'SAVED') continue;
    final date = report.effectiveDate;
    // One reading per series per report, even if a document repeats a test.
    final seenInReport = <String>{};

    for (final panel in report.panels) {
      for (final result in panel.results) {
        final value = result.value;
        if (value == null || !value.isFinite) continue;
        final parameter = canonicalParameter(result.testName);
        final id = '${parameter.key}|${_normalizeUnit(result.unit)}';
        if (!seenInReport.add(id)) continue;

        final entry = series[id] ??
            (name: parameter.name, unit: result.unit, points: <TrendPoint>[]);
        entry.points.add(TrendPoint(
          date: date,
          value: value,
          status: result.status,
          referenceLow: result.referenceLow,
          referenceHigh: result.referenceHigh,
          reportId: report.id,
        ));
        series[id] = entry;
      }
    }
  }

  final trends = <LabTrend>[];
  for (final e in series.entries) {
    if (e.value.points.length < 2) continue;
    final points = [...e.value.points]..sort((a, b) => a.date.compareTo(b.date));
    trends.add(LabTrend(
      id: e.key,
      parameterKey: e.key.split('|').first,
      name: e.value.name,
      unit: e.value.unit,
      points: points,
      direction: directionOf(points),
      latest: points.last,
    ));
  }

  // Most history first, then the most recently updated.
  trends.sort((a, b) {
    final byCount = b.points.length.compareTo(a.points.length);
    return byCount != 0 ? byCount : b.latest.date.compareTo(a.latest.date);
  });
  return trends;
}

/// The trend a given printed result belongs to, if there is one.
LabTrend? findTrendFor(List<LabTrend> trends, String testName, String? unit) {
  final id = '${canonicalParameter(testName).key}|${_normalizeUnit(unit)}';
  for (final t in trends) {
    if (t.id == id) return t;
  }
  return null;
}

/// Turns a lab report into the opening message for Nova, so "Ask Nova about
/// this" starts from the patient's own data instead of an empty chat. Written in
/// the patient's voice and placed in the composer — never sent automatically.
/// Ported from `features/healthRecords/novaContext.ts`.
String buildLabReportChatMessage(LabReport report) {
  String day(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String? range(double? low, double? high, String? unit) {
    final u = (unit != null && unit.isNotEmpty) ? ' $unit' : '';
    if (low != null && high != null) return '${num(low)}–${num(high)}$u';
    if (low != null) return 'above ${num(low)}$u';
    if (high != null) return 'below ${num(high)}$u';
    return null;
  }

  String describe(LabResult r) {
    final String value;
    if (r.value != null) {
      value = '${num(r.value!)}${(r.unit != null && r.unit!.isNotEmpty) ? ' ${r.unit}' : ''}';
    } else {
      value = r.valueText ?? 'no value';
    }
    final printed = range(r.referenceLow, r.referenceHigh, r.unit) ?? r.referenceText;
    return printed != null
        ? '- ${r.testName}: $value (printed range $printed)'
        : '- ${r.testName}: $value';
  }

  final results = report.allResults;
  // Values outside their printed range first — they are what a reader asks about.
  final flagged = results.where((r) => r.status != 'NORMAL').toList();
  final normal = results.where((r) => r.status == 'NORMAL').toList();
  final shown = [...flagged, ...normal].take(20).toList();

  final lines = <String>[
    "I'd like to understand my ${labReportTypeLabel(report.reportType)} from ${day(report.effectiveDate)}.",
    '',
    ...shown.map(describe),
  ];
  if (results.length > shown.length) {
    lines.add('- …and ${results.length - shown.length} more values');
  }
  lines.addAll(['', 'Can you explain what these results mean and what I could ask my doctor?']);
  return lines.join('\n');
}
