import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/report.dart';
import '../../../../data/models/timeline.dart';
import '../../../../state/reports_provider.dart';
import '../../../../state/uploads_provider.dart';
import '../../../widgets/common.dart';

const _filters = ['All', 'Imaging', 'Visits', 'Lab results', 'Prescriptions'];

/// Stored documents without an extraction pipeline — scans, visit notes,
/// anything else. Ported from `DocumentsList.tsx`.
class DocumentsList extends ConsumerStatefulWidget {
  final VoidCallback onAdd;
  const DocumentsList({super.key, required this.onAdd});

  @override
  ConsumerState<DocumentsList> createState() => _DocumentsListState();
}

class _DocumentsListState extends ConsumerState<DocumentsList> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(reportsProvider.notifier).load();
    });
  }

  Future<void> _remove(String id) async {
    final ok = await confirmDialog(context, message: 'Remove this document from your records?', confirmLabel: 'Remove');
    if (!ok) return;
    try {
      await ref.read(reportsProvider.notifier).removeReport(id);
      AppMessenger.success('Document removed');
    } catch (_) {
      /* toasted by the API client */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(reportsProvider);
    final uploading = ref.watch(uploadsProvider);
    final shown = _filter == 'All'
        ? state.reports
        : state.reports.where((r) => r.category == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _filters)
                RoundedChip(label: f, selected: _filter == f, onTap: () => setState(() => _filter = f)),
            ],
          ),
        ),
        if (uploading.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                for (var i = 0; i < uploading.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          uploading[i].status == 'error'
                              ? PhosphorIconsRegular.warningCircle
                              : PhosphorIconsRegular.cloudArrowUp,
                          size: 16,
                          color: uploading[i].status == 'error' ? AppColors.coral : AppColors.teal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uploading[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.08,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  color: t.ink,
                                ),
                              ),
                              Text(
                                uploading[i].status == 'error'
                                    ? 'Upload failed'
                                    : 'Uploading… ${uploading[i].progress}%',
                                style: TextStyle(fontSize: 12.16, height: 1.5, color: t.ink3),
                              ),
                            ],
                          ),
                        ),
                        if (uploading[i].status == 'error')
                          GestureDetector(
                            onTap: () => ref.read(uploadsProvider.notifier).retry(uploading[i].id),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (state.isLoaded && shown.isEmpty && uploading.isEmpty)
          DashedBox(
            radius: 16,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.folderOpen, size: 35.2, color: t.ink3),
                const SizedBox(height: 12),
                Text(
                  'No documents${_filter == 'All' ? ' yet' : ' in this category'}',
                  style: TextStyle(
                    fontSize: 15.68,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scans, discharge summaries and visit notes are kept here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                ),
                const SizedBox(height: 20),
                WebButton(
                  label: 'Add to My Health',
                  icon: PhosphorIconsFill.plusCircle,
                  onTap: widget.onAdd,
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _DocumentTile(
                  report: shown[i],
                  onOpen: () => context.push('/reports/${shown[i].id}'),
                  onRemove: () => _remove(shown[i].id),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final Report report;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _DocumentTile({required this.report, required this.onOpen, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = documentIconFor(report.mimeType);
    final created = Formatters.tryParse(report.createdAt);
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              AccentIconBox(icon: v.icon, accent: v.accent, size: 40, radius: 11, iconSize: 18.4),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.04,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      '${report.category} · ${created != null ? Formatters.dateTime(created) : ''} · ${Formatters.fileSize(report.sizeBytes)}',
                      style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(PhosphorIconsRegular.trash, size: 16, color: t.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
