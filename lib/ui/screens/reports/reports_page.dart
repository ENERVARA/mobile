import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report.dart';
import '../../../state/reports_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pill_badge.dart';
import 'widgets/upload_sheet.dart';

/// Reports & History — lists the user's uploaded medical records and opens the
/// upload sheet. Ported from `src/features/reports/pages/ReportsPage.tsx`.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  /// null = "All". Mirrors the web's category filter row.
  String? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(reportsProvider.notifier).load();
    });
  }

  ({IconData icon, Color accent}) _reportIcon(String mime) {
    if (mime == 'application/pdf') {
      return (icon: PhosphorIconsFill.filePdf, accent: AppColors.coral);
    }
    if (mime.startsWith('image/')) {
      return (icon: PhosphorIconsFill.image, accent: AppColors.teal);
    }
    return (icon: PhosphorIconsFill.file, accent: AppColors.lav);
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(reportsProvider.notifier).removeReport(id);
      AppMessenger.success('Report removed');
    } catch (_) {
      /* toasted by the api interceptor */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(reportsProvider);
    final reports = _category == null
        ? state.reports
        : state.reports.where((r) => r.category == _category).toList();
    final isEmpty = state.isLoaded && reports.isEmpty;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const PageHeader(
            title: 'Reports & History',
            subtitle: 'Every record, all in one place.',
          ),
          AppButton(
            label: 'Upload record',
            icon: PhosphorIconsBold.uploadSimple,
            onPressed: () => showUploadSheet(context),
          ),
          const SizedBox(height: 16),
          // ── Category filter ──
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in <String?>[null, ...reportCategories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _category == c ? AppColors.teal : t.soft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _category == c ? AppColors.teal : t.line),
                        ),
                        child: Text(
                          c ?? 'All',
                          style: TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w600,
                            color: _category == c ? Colors.white : t.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!state.isLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (isEmpty)
            _EmptyState(onUpload: () => showUploadSheet(context))
          else
            ...reports.map((r) {
              final look = _reportIcon(r.mimeType);
              final created = Formatters.tryParse(r.createdAt) ?? DateTime.now();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  onTap: () => context.push('/reports/${r.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: look.accent.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(look.icon, size: 20, color: look.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                PillBadge(
                                  variant: PillVariant.gray,
                                  label: r.category,
                                  dot: false,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${Formatters.fileSize(r.sizeBytes)} · ${Formatters.timeAgo(created)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.8, color: t.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _remove(r.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            PhosphorIconsRegular.trash,
                            size: 18,
                            color: t.ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Icon(PhosphorIconsRegular.cloudArrowUp, size: 40, color: t.ink3),
          const SizedBox(height: 12),
          Text(
            'No records yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload your first medical document to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.8, color: t.ink2),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Upload your first file',
            icon: PhosphorIconsBold.uploadSimple,
            expand: false,
            onPressed: onUpload,
          ),
        ],
      ),
    );
  }
}
