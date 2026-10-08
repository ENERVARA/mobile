import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/accent.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/lab_trends.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/models/lab_report.dart';
import '../../../state/lab_reports_provider.dart';
import '../../../state/lab_trends_provider.dart';
import '../../../state/nova_ui_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import 'lab_status.dart';
import 'widgets/lab_result_row.dart';

/// Values outside their printed range lead; the rest fill up to the limit.
const _keyResultLimit = 3;

List<LabResult> _keyResults(LabReport report) {
  final all = report.allResults;
  final flagged = all.where((r) => r.status != 'NORMAL');
  final normal = all.where((r) => r.status == 'NORMAL');
  return [...flagged, ...normal].take(_keyResultLimit).toList();
}

/// Report detail. Ported from `LabReportDetailPage.tsx`.
///
/// Presents what the document said and how each value compares with the
/// reference range printed on it — never an interpretation. Every abnormal marker
/// points the reader back to the original document, which stays one tap away via a
/// short-lived download URL.
class LabReportDetailPage extends ConsumerStatefulWidget {
  final String id;
  const LabReportDetailPage({super.key, required this.id});

  @override
  ConsumerState<LabReportDetailPage> createState() => _LabReportDetailPageState();
}

class _LabReportDetailPageState extends ConsumerState<LabReportDetailPage> {
  /// `undefined` (loading) vs `null` (not found) in the web — here `_loaded`.
  LabReport? _report;
  bool _loaded = false;
  bool _opening = false;
  bool _showComplete = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(labReportsServiceProvider).getReport(widget.id);
      if (mounted) setState(() => _report = r);
    } catch (_) {
      if (mounted) setState(() => _report = null);
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// Fetches a fresh, short-lived URL every time rather than caching one: the
  /// link expires in minutes, and a stale one would fail silently.
  Future<void> _viewOriginal() async {
    setState(() => _opening = true);
    try {
      final ticket = await ref.read(labReportsServiceProvider).getDownloadUrl(widget.id);
      final ok = await launchUrl(Uri.parse(ticket.url), mode: LaunchMode.externalApplication);
      if (!ok) AppMessenger.error('Could not open the original report');
    } catch (_) {
      AppMessenger.error('Could not open the original report');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, message: 'Delete this lab report? This cannot be undone.');
    if (!ok) return;
    try {
      await ref.read(labReportsProvider.notifier).removeReport(widget.id);
      AppMessenger.success('Report deleted');
      if (mounted) context.go('/health-records');
    } catch (_) {
      /* toasted by the API client */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final report = _report;

    Widget back() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/health-records'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '← Back to Health Records',
              style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
            ),
          ),
        );

    if (!_loaded) {
      return const ShellPage(
        children: [
          Skeleton(width: 128, height: 16, radius: 8),
          SizedBox(height: 20),
          Skeleton(height: 96, radius: 18),
          SizedBox(height: 16),
          Skeleton(height: 256, radius: 18),
        ],
      );
    }

    if (report == null) {
      return ShellPage(
        children: [
          back(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: Column(
              children: [
                Text(
                  'Report not found',
                  style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'It may have been deleted, or the link is incorrect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final trends = ref.watch(labTrendsProvider).valueOrNull?.trends ?? const <LabTrend>[];
    final keys = _keyResults(report);
    final history = <({LabResult result, LabTrend trend})>[
      for (final r in keys)
        if (findTrendFor(trends, r.testName, r.unit) != null)
          (result: r, trend: findTrendFor(trends, r.testName, r.unit)!),
    ];
    final status = kReportStatusMeta[report.status] ?? kReportStatusMeta['PROCESSING']!;
    final effective = Formatters.tryParse(report.effectiveDate);
    final reportDate = Formatters.tryParse(report.reportDate);
    final uploaded = Formatters.tryParse(report.uploadedAt ?? report.createdAt);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12.48,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9984,
              height: 1.5,
              color: t.ink3,
            ),
          ),
        );

    return ShellPage(
      children: [
        back(),

        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AccentIconBox(
                icon: PhosphorIconsFill.flask,
                accent: Accent.teal,
                size: 48,
                radius: 13,
                iconSize: 20.8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAB REPORT · ${effective != null ? Formatters.dateFull(effective).toUpperCase() : ''}',
                      style: TextStyle(
                        fontSize: 11.84,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.184,
                        height: 1.5,
                        color: t.ink3,
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          report.reportType,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.48,
                            height: 1.5,
                            color: t.ink,
                          ),
                        ),
                        AccentPill(
                          label: status.label,
                          accent: status.accent,
                          fontSize: 11.84,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        ),
                      ],
                    ),
                    Text(
                      labReportTypeLabel(report.reportType),
                      style: TextStyle(fontSize: 15.2, height: 1.5, color: t.ink2),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 2,
                        children: [
                          Text(
                            'Report date: ${reportDate != null ? Formatters.dateFull(reportDate) : 'Not stated'}',
                            style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                          ),
                          Text(
                            'Uploaded: ${uploaded != null ? Formatters.dateFull(uploaded) : ''}',
                            style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                          ),
                          if (report.metadata.labName != null)
                            Text(
                              report.metadata.labName!,
                              style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (report.status == 'FAILED' && report.failureReason != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(PhosphorIconsFill.warningCircle, size: 17.6, color: AppColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.failureReason!,
                    style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                  ),
                ),
              ],
            ),
          ),

        label('Summary'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${report.summary.markerCount}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' parameter${report.summary.markerCount == 1 ? '' : 's'} identified',
                ),
              ],
            ),
            style: TextStyle(fontSize: 15.2, height: 1.5, color: t.ink),
          ),
        ),
        _SummaryTiles(summary: report.summary),

        if (keys.isNotEmpty) ...[
          const SizedBox(height: 20),
          label('Key results'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < keys.length; i++) LabResultRow(result: keys[i], first: i == 0),
              ],
            ),
          ),
        ],

        if (report.panels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showComplete = !_showComplete),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showComplete ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.listBullets,
                      size: 16,
                      color: t.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showComplete ? 'Hide complete report' : 'View complete report',
                      style: TextStyle(
                        fontSize: 13.76,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showComplete)
            for (final panel in report.panels) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      panel.name,
                      style: TextStyle(
                        fontSize: 16.8,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${panel.results.length} marker${panel.results.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12.48, color: t.ink3),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < panel.results.length; i++)
                      LabResultRow(result: panel.results[i], first: i == 0),
                  ],
                ),
              ),
            ],
        ],

        if (report.panels.isEmpty) ...[
          const SizedBox(height: 20),
          DashedBox(
            radius: 16,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No values were extracted from this document.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
            ),
          ),
        ],

        // Earlier readings of the same tests from the patient's other saved
        // reports — shown only when comparable data exists.
        if (history.isNotEmpty) ...[
          const SizedBox(height: 20),
          label('History'),
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < history[i].trend.points.length; j++)
                    Padding(
                      padding: EdgeInsets.only(top: j == 0 ? 0 : 4),
                      child: Text(
                        () {
                          final p = history[i].trend.points[j];
                          final v = p.value == p.value.roundToDouble()
                              ? p.value.toInt().toString()
                              : p.value.toString();
                          return '${history[i].trend.name} · ${Formatters.eventDate(p.date, withYear: true)} → $v ${history[i].trend.unit ?? ''}';
                        }(),
                        style: TextStyle(
                          fontSize: 13.76,
                          height: 1.5,
                          fontWeight: history[i].trend.points[j].reportId == report.id
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: history[i].trend.points[j].reportId == report.id ? t.ink : t.ink2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Text(
            'These values were read from the document you uploaded, and each is compared with the reference range printed on that same document. Ranges vary between laboratories. This is not a medical assessment — always compare with the original report and talk to your doctor about what the results mean for you.',
            style: TextStyle(fontSize: 13.12, height: 1.625, color: t.ink2),
          ),
        ),

        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            WebButton(
              label: _opening ? 'Opening…' : 'View original report',
              icon: PhosphorIconsRegular.fileArrowDown,
              loading: _opening,
              onTap: _opening ? null : _viewOriginal,
            ),
            if (report.panels.isNotEmpty)
              WebButton(
                label: 'Ask Nova about this report',
                icon: PhosphorIconsFill.chatCircleDots,
                variant: WebButtonVariant.ghost,
                onTap: () => ref
                    .read(novaUiProvider.notifier)
                    .openWithDraft(kDefaultSpecialitySlug, buildLabReportChatMessage(report)),
              ),
            WebButton(
              label: 'Delete',
              icon: PhosphorIconsRegular.trash,
              variant: WebButtonVariant.dangerOutline,
              onTap: _delete,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  final LabReportSummary summary;
  const _SummaryTiles({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tiles = <({String label, int value, Accent? accent})>[
      (label: 'Total markers', value: summary.markerCount, accent: null),
      (label: 'In range', value: summary.normalCount, accent: Accent.teal),
      (label: 'Above range', value: summary.highCount, accent: Accent.coral),
      (label: 'Below range', value: summary.lowCount, accent: Accent.cyan),
      (label: 'Needs review', value: summary.reviewCount, accent: Accent.amber),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // `grid-cols-2 gap-3` at mobile width
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tile.value}',
                        style: TextStyle(
                          fontSize: 22.4,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: tile.accent?.style.color ?? t.ink,
                        ),
                      ),
                      Text(
                        tile.label,
                        style: TextStyle(fontSize: 12.16, height: 1.5, color: t.ink3),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
