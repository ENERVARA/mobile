import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report.dart';
import '../../../state/reports_provider.dart';
import '../../widgets/app_button.dart';

/// A single report — header, image/PDF preview and a delete action. Ported from
/// `src/features/reports/pages/ReportDetailPage.tsx`.
class ReportDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ReportDetailPage({super.key, required this.id});

  @override
  ConsumerState<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends ConsumerState<ReportDetailPage> {
  Future<Uint8List>? _blobFuture;
  bool _downloading = false;

  /// Fetch the JWT-protected blob, write it to a temp file and hand it to the
  /// OS viewer — the mobile equivalent of the web's Download button.
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

  ({IconData icon, Color accent}) _reportIcon(String mime) {
    if (mime == 'application/pdf') {
      return (icon: PhosphorIconsFill.filePdf, accent: AppColors.coral);
    }
    if (mime.startsWith('image/')) {
      return (icon: PhosphorIconsFill.image, accent: AppColors.teal);
    }
    return (icon: PhosphorIconsFill.file, accent: AppColors.lav);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(reportsProvider.notifier).removeReport(widget.id);
      if (!mounted) return;
      AppMessenger.success('Report deleted');
      context.pop();
    } catch (_) {
      /* toasted by the api interceptor */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(reportsProvider);

    Report? report;
    for (final r in state.reports) {
      if (r.id == widget.id) {
        report = r;
        break;
      }
    }

    if (report != null && report.isImage && _blobFuture == null) {
      _blobFuture = ref.read(reportsServiceProvider).fetchBlob(report.id);
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.arrowLeft, size: 16, color: t.ink2),
                    const SizedBox(width: 6),
                    Text(
                      'Back to Reports',
                      style: TextStyle(fontSize: 13.8, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (report == null)
              _notFoundOrLoading(t, state.isLoaded)
            else
              _content(context, t, report),
          ],
        ),
      ),
    );
  }

  Widget _notFoundOrLoading(AppTokens t, bool isLoaded) {
    if (!isLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Text(
            'Report not found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'It may have been deleted, or the link is incorrect.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.6, color: t.ink2),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppTokens t, Report report) {
    final look = _reportIcon(report.mimeType);
    final created = Formatters.tryParse(report.createdAt);
    final meta = <String>[
      report.category,
      if (created != null) Formatters.dateMedium(created),
      Formatters.fileSize(report.sizeBytes),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: look.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(look.icon, size: 24, color: look.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: t.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(meta, style: TextStyle(fontSize: 13.6, color: t.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _preview(t, report),
          const SizedBox(height: 20),
          AppButton(
            label: _downloading ? 'Opening…' : 'Download',
            icon: PhosphorIconsBold.downloadSimple,
            loading: _downloading,
            onPressed: () => _download(report),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            icon: PhosphorIconsRegular.trash,
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _preview(AppTokens t, Report report) {
    if (report.isImage) {
      return FutureBuilder<Uint8List>(
        future: _blobFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _previewBox(
              t,
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return _previewBox(
              t,
              Text('Preview unavailable', style: TextStyle(fontSize: 13, color: t.ink3)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              snap.data!,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          );
        },
      );
    }

    // PDF / other — no inline preview.
    return _previewBox(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsFill.filePdf, size: 48, color: AppColors.coral),
          const SizedBox(height: 12),
          Text(
            report.isPdf ? 'PDF document' : 'Document',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'This file opens in an external viewer.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
        ],
      ),
    );
  }

  Widget _previewBox(AppTokens t, Widget child) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Center(child: child),
    );
  }
}
