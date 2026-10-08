import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/accent.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/lab_report.dart';
import '../../../../state/lab_reports_provider.dart';
import '../../../widgets/common.dart';
import '../../reports/widgets/lab_result_row.dart';
import '../../../widgets/skeleton.dart';
import '../../reports/lab_status.dart';

/// The Lab Results tab — a real, data-driven listing. Ported from
/// `LabResultsTab.tsx`.
///
/// Search, filters and sorting are applied SERVER-SIDE via the list query, so
/// this scales past whatever fits in memory.
class LabResultsTab extends ConsumerStatefulWidget {
  final VoidCallback onScanNew;
  const LabResultsTab({super.key, required this.onScanNew});

  @override
  ConsumerState<LabResultsTab> createState() => _LabResultsTabState();
}

class _LabResultsTabState extends ConsumerState<LabResultsTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(labReportsProvider).query.search;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(labReportsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    // Debounced so typing does not fire a request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final s = ref.read(labReportsProvider);
      if (v != s.query.search) {
        ref.read(labReportsProvider.notifier).setQuery(s.query.copyWith(search: v));
      }
    });
  }

  Future<void> _delete(LabReportListItem report) async {
    final ok = await confirmDialog(
      context,
      message: 'Delete this ${report.reportType} report? This cannot be undone.',
    );
    if (!ok) return;
    try {
      await ref.read(labReportsProvider.notifier).removeReport(report.id);
      AppMessenger.success('Report deleted');
    } catch (_) {
      /* toasted by the API client */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = ref.watch(labReportsProvider);
    final query = s.query;
    final notifier = ref.read(labReportsProvider.notifier);
    final showSkeletons = s.isLoading && !s.isLoaded;
    final isEmpty = s.isLoaded && !s.isLoading && s.reports.isEmpty;

    Widget select(String value, List<({String value, String label})> options, ValueChanged<String?> onChanged) =>
        IntrinsicWidth(
          child: WebSelect<String>(
            value: value,
            options: options,
            onChanged: onChanged,
            radius: 12,
            fontSize: 13.44,
            fontWeight: FontWeight.w600,
            textColor: t.ink2,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `flex flex-wrap items-center gap-2.5` — the search takes the first line
        // with the type filter; status + sort wrap beneath.
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: 'Search lab reports…',
                      controller: _search,
                      onChanged: _onSearch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  select(
                    query.reportType,
                    [
                      (value: 'ALL', label: 'All types'),
                      for (final type in kLabReportTypes) (value: type, label: type),
                    ],
                    (v) => notifier.setQuery(query.copyWith(reportType: v ?? 'ALL')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  select(
                    query.status,
                    [
                      (value: 'ALL', label: 'Any status'),
                      for (final st in kLabReportStatuses)
                        (value: st, label: kReportStatusMeta[st]!.label),
                    ],
                    (v) => notifier.setQuery(query.copyWith(status: v ?? 'ALL')),
                  ),
                  select(
                    query.sort,
                    [for (final so in kLabReportSorts) (value: so, label: kLabReportSortLabels[so]!)],
                    (v) => notifier.setQuery(query.copyWith(sort: v ?? 'DATE_DESC')),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showSkeletons)
          Column(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                const _CardSkeleton(),
              ],
            ],
          ),
        if (isEmpty)
          DashedBox(
            radius: 16,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.flask, size: 40, color: t.ink3),
                const SizedBox(height: 12),
                Text(
                  query.hasFilters ? 'No reports match those filters' : 'No lab results yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  query.hasFilters
                      ? 'Try a different search or clear the filters.'
                      : 'Add a lab report and we will pull out the values for you to review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
                ),
                const SizedBox(height: 20),
                if (query.hasFilters)
                  WebButton(
                    label: 'Clear filters',
                    variant: WebButtonVariant.ghost,
                    onTap: () {
                      _search.clear();
                      notifier.setQuery(const LabListQuery());
                    },
                  )
                else
                  WebButton(
                    label: 'Add to My Health',
                    icon: PhosphorIconsFill.plusCircle,
                    onTap: widget.onScanNew,
                  ),
              ],
            ),
          ),
        if (!showSkeletons && s.reports.isNotEmpty)
          Opacity(
            opacity: s.isLoading ? 0.6 : 1,
            child: Column(
              children: [
                for (var i = 0; i < s.reports.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _LabReportCard(
                    report: s.reports[i],
                    onOpen: () => context.push('/lab-reports/${s.reports[i].id}'),
                    onDelete: () => _delete(s.reports[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LabReportCard extends StatelessWidget {
  final LabReportListItem report;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _LabReportCard({required this.report, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final needsReview = report.summary.abnormalCount > 0;
    final reportDate = Formatters.tryParse(report.reportDate);
    final uploaded = Formatters.tryParse(report.uploadedAt ?? report.createdAt);

    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AccentIconBox(
                      icon: PhosphorIconsFill.flask,
                      accent: Accent.teal,
                      size: 40,
                      radius: 11,
                      iconSize: 17.6,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  report.reportType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                    color: t.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ReportStatusPill(status: report.status, fontSize: 11.2),
                            ],
                          ),
                          Text(
                            labReportTypeLabel(report.reportType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(PhosphorIconsRegular.trash, size: 16, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Report date: ${reportDate != null ? Formatters.dateTime(reportDate) : '—'}',
                      style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                    ),
                    Text(
                      'Uploaded: ${uploaded != null ? Formatters.dateTime(uploaded) : '—'}',
                      style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${report.summary.markerCount}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' markers', style: TextStyle(color: t.ink2)),
                            TextSpan(
                              text:
                                  '  ${labSummaryLine(report.summary.abnormalCount, report.summary.markerCount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: needsReview ? AppColors.amber : AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View report',
                          style: TextStyle(
                            fontSize: 13.12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: AppColors.teal,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(PhosphorIconsRegular.caretRight, size: 13.12, color: AppColors.teal),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 40, height: 40, radius: 11),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 96, height: 16, radius: 8),
                    SizedBox(height: 6),
                    Skeleton(width: 160, height: 12, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Skeleton(width: 224, height: 12, radius: 8),
          SizedBox(height: 12),
          Skeleton(height: 16, radius: 8),
        ],
      ),
    );
  }
}
