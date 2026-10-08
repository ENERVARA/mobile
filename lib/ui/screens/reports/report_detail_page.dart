import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report.dart';
import '../../../data/models/timeline.dart';
import '../../../state/reports_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

/// A single stored document — header, image preview, download and delete. Ported
/// from `features/reports/pages/ReportDetailPage.tsx`.
class ReportDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ReportDetailPage({super.key, required this.id});

  @override
  ConsumerState<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends ConsumerState<ReportDetailPage> {
  Future<Uint8List>? _blobFuture;
  bool _downloading = false;

  /// Fetch the JWT-protected blob, write it to a temp file and hand it to the OS
  /// viewer — the mobile equivalent of the web's Download button.
  Future<void> _download(Report report) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(reportsServiceProvider).fetchBlob(report.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${report.fileName}');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        AppMessenger.error('No app available to open this file');
      }
    } catch (_) {
      AppMessenger.error('Could not download this file');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(reportsProvider);
      if (!s.isLoaded && !s.isLoading) ref.read(reportsProvider.notifier).load();
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await confirmDialog(context, message: 'Delete this report? This cannot be undone.');
    if (!ok) return;
    try {
      await ref.read(reportsProvider.notifier).removeReport(widget.id);
      AppMessenger.success('Report deleted');
      if (mounted) context.go('/health-records');
    } catch (_) {
      /* toasted by the API client */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(reportsProvider);
    final report = state.reports.where((r) => r.id == widget.id).firstOrNull;

    if (report != null && report.isImage && _blobFuture == null) {
      _blobFuture = ref.read(reportsServiceProvider).fetchBlob(report.id);
    }

    return ShellPage(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/health-records'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '← Back to Health Records',
              style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
            ),
          ),
        ),
        if (report == null && !state.isLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: AppSpinner(size: 40)),
          )
        else if (report == null)
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
          )
        else
          _content(context, report),
      ],
    );
  }

  Widget _content(BuildContext context, Report report) {
    final t = context.tokens;
    final look = documentIconFor(report.mimeType);
    final created = Formatters.tryParse(report.createdAt);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                AccentIconBox(
                  icon: look.icon,
                  accent: look.accent,
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
                        report.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19.2,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        '${report.category} · ${created != null ? Formatters.dateFull(created) : ''} · ${Formatters.fileSize(report.sizeBytes)}',
                        style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (report.isImage)
            FutureBuilder<Uint8List>(
              future: _blobFuture,
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  constraints: const BoxConstraints(maxHeight: 480),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(snap.data!, fit: BoxFit.contain),
                );
              },
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Opacity(
                opacity: _downloading ? 0.6 : 1,
                child: WebButton(
                  label: _downloading ? 'Downloading…' : 'Download',
                  icon: PhosphorIconsRegular.downloadSimple,
                  onTap: _downloading ? null : () => _download(report),
                ),
              ),
              WebButton(
                label: 'Delete',
                icon: PhosphorIconsRegular.trash,
                variant: WebButtonVariant.dangerOutline,
                onTap: _confirmDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
