import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/lab_trends.dart';
import '../data/models/lab_report.dart';
import 'lab_reports_provider.dart';

/// Trends need every value, but the list endpoint returns summaries only, so
/// each saved report's detail is fetched once and cached for the session. The
/// cache key includes `updatedAt`, so a corrected report is refetched. Bounded to
/// the most recent reports to keep the request count sane. Ported from
/// `useLabTrends.ts`.
const _maxReports = 40;
final Map<String, LabReport> _detailCache = {};

class LabTrendsData {
  final List<LabTrend> trends;

  /// Saved reports the trends were built from.
  final int reportCount;
  const LabTrendsData({this.trends = const [], this.reportCount = 0});
}

final labTrendsProvider = FutureProvider.autoDispose<LabTrendsData>((ref) async {
  try {
    final svc = ref.read(labReportsServiceProvider);
    final list = await svc.listReports(status: 'SAVED', sort: 'DATE_DESC');
    final reports = await Future.wait(
      list.take(_maxReports).map((item) async {
        final key = '${item.id}:${item.updatedAt}';
        final cached = _detailCache[key];
        if (cached != null) return cached;
        final detail = await svc.getReport(item.id);
        _detailCache[key] = detail;
        return detail;
      }),
    );
    return LabTrendsData(trends: buildLabTrends(reports), reportCount: reports.length);
  } catch (_) {
    return const LabTrendsData();
  }
});
