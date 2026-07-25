import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report.dart';
import '../../../state/reports_provider.dart';
import '../../widgets/coming_soon.dart';

/// Medical History — ported from `src/features/history/pages/HistoryPage.tsx`.
///
/// The page duplicates Reports data (loaded via [reportsProvider]) rendered as a
/// month-grouped timeline teaser, sitting UNDER a `ComingSoon` overlay that greys
/// it out — a dedicated Medical History experience is still to come.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Load reports for the teaser once the first frame is scheduled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsProvider.notifier).load();
    });
  }

  static const _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(reportsProvider);
    final reports = state.reports;
    final isEmpty = state.isLoaded && reports.isEmpty;

    // Group reports by "Month Year", newest first.
    final sorted = [...reports]..sort((a, b) {
        final da = Formatters.tryParse(a.createdAt) ?? DateTime(0);
        final db = Formatters.tryParse(b.createdAt) ?? DateTime(0);
        return db.compareTo(da);
      });
    final grouped = <String, List<Report>>{};
    for (final r in sorted) {
      final d = Formatters.tryParse(r.createdAt) ?? DateTime.now();
      grouped.putIfAbsent(_monthYear(d), () => []).add(r);
    }

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          // ── Teaser (greyed underneath the overlay) ──
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // Header: title + subtitle + "Upload New" outline button.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical History',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEmpty
                              ? 'Upload your medical records to keep them in one place'
                              : '${reports.length} ${reports.length == 1 ? 'file' : 'files'} · All your medical documents in one place',
                          style: TextStyle(fontSize: 14, color: t.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _UploadNewButton(),
                ],
              ),
              const SizedBox(height: 24),

              // Quick upload zone (collapsed, non-interactive teaser).
              _UploadZone(),
              const SizedBox(height: 24),

              // Timeline / empty state.
              if (isEmpty)
                _EmptyState()
              else
                for (final entry in grouped.entries) ...[
                  _MonthGroup(month: entry.key, reports: entry.value),
                  const SizedBox(height: 32),
                ],
            ],
          ),

          // ── Coming-soon overlay ──
          const ComingSoon(
            asOverlay: true,
            title: 'Medical History is on the way',
            description:
                'This view now duplicates Reports — a dedicated Medical History experience is still coming. Head to Reports for your uploaded records in the meantime.',
          ),
        ],
      ),
    );
  }
}

class _UploadNewButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.cloudArrowUp, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          const Text(
            'Upload New',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(PhosphorIconsDuotone.cloudArrowUp, size: 20, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upload new records',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: t.ink,
              ),
            ),
          ),
          Icon(PhosphorIconsRegular.caretRight, size: 16, color: t.ink3),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line, style: BorderStyle.solid),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Column(
        children: [
          Icon(PhosphorIconsDuotone.cloudArrowUp, size: 48, color: t.ink3),
          const SizedBox(height: 12),
          Text(
            'No records yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload your first medical document to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.ink2),
          ),
        ],
      ),
    );
  }
}

class _MonthGroup extends StatelessWidget {
  final String month;
  final List<Report> reports;
  const _MonthGroup({required this.month, required this.reports});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header.
        Row(
          children: [
            Text(
              month,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink),
            ),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 1, color: t.line)),
            const SizedBox(width: 12),
            Text(
              '${reports.length} ${reports.length == 1 ? 'file' : 'files'}',
              style: TextStyle(fontSize: 12, color: t.ink3),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Timeline column with a left rail line + dots.
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Stack(
            children: [
              Positioned(
                left: -13,
                top: 12,
                bottom: 12,
                child: Container(width: 2, color: t.line),
              ),
              Column(
                children: [
                  for (var i = 0; i < reports.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _TimelineRow(report: reports[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Report report;
  const _TimelineRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parsed = Formatters.tryParse(report.createdAt);
    final dateLabel = parsed != null ? Formatters.dateMedium(parsed) : '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Timeline dot.
        Positioned(
          left: -18,
          top: 16,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
              border: Border.all(color: t.card, width: 2),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FileIcon(mimeType: report.mimeType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(dateLabel, style: TextStyle(fontSize: 12, color: t.ink3)),
                        Text('· ${Formatters.fileSize(report.sizeBytes)}',
                            style: TextStyle(fontSize: 12, color: t.ink3)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIconsDuotone.checkCircle,
                                size: 11, color: AppColors.success),
                            const SizedBox(width: 4),
                            const Text(
                              'Uploaded',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileIcon extends StatelessWidget {
  final String mimeType;
  const _FileIcon({required this.mimeType});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPdf = mimeType == 'application/pdf';
    final isImage = mimeType.startsWith('image/');

    Color bg;
    Color fg;
    IconData icon;
    if (isPdf) {
      bg = AppColors.danger.withValues(alpha: 0.12);
      fg = AppColors.danger;
      icon = PhosphorIconsDuotone.filePdf;
    } else if (isImage) {
      bg = AppColors.teal.withValues(alpha: 0.12);
      fg = AppColors.teal;
      icon = PhosphorIconsDuotone.image;
    } else {
      bg = t.line;
      fg = t.ink2;
      icon = PhosphorIconsRegular.file;
    }

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }
}
