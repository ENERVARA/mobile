import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/models/report.dart';
import '../../../../state/reports_provider.dart';
import '../../../widgets/app_button.dart';

/// Opens the bottom sheet used to pick + categorise a new medical record and
/// upload it with live progress. Mirrors the web `FileUploader` dropzone.
Future<void> showUploadSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Attach to the ROOT navigator's overlay so the sheet is guaranteed to
    // paint above the shell's fixed bottom nav / raised Nova button, not just
    // whatever the nearest Navigator happens to be.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const UploadSheet(),
  );
}

class UploadSheet extends ConsumerStatefulWidget {
  const UploadSheet({super.key});

  @override
  ConsumerState<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<UploadSheet> {
  String? _path;
  String? _fileName;
  String _category = reportCategories.first;
  bool _uploading = false;
  int _progress = 0;

  IconData _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return PhosphorIconsFill.filePdf;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return PhosphorIconsFill.image;
    }
    return PhosphorIconsFill.file;
  }

  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'dcm'];
  static const _maxBytes = 10 * 1024 * 1024;

  /// Enforce the same limits the server does (10 MB, PDF/JPEG/PNG/DICOM) before
  /// spending the upload — the web dropzone rejects these client-side too.
  bool _accept(String path, String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!_allowedExtensions.contains(ext)) {
      AppMessenger.error('Unsupported file type — use PDF, JPEG, PNG or DICOM');
      return false;
    }
    if (File(path).lengthSync() > _maxBytes) {
      AppMessenger.error('That file is over the 10MB limit');
      return false;
    }
    return true;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    final file = result?.files.single;
    if (file?.path == null) return;
    if (!_accept(file!.path!, file.name)) return;
    setState(() {
      _path = file.path;
      _fileName = file.name;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!_accept(picked.path, picked.name)) return;
    setState(() {
      _path = picked.path;
      _fileName = picked.name;
    });
  }

  Future<void> _upload() async {
    final path = _path;
    if (path == null || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      await ref.read(reportsProvider.notifier).upload(
            path,
            fileName: _fileName,
            category: _category,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppMessenger.success('Report uploaded');
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
      AppMessenger.error('Could not upload this file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Extra bottom space (≈ the bottom nav's bar height + the raised Nova
      // button's overhang, +buffer) so the Upload action clears them entirely.
      padding: EdgeInsets.fromLTRB(20, 12, 20, 90 + bottomInset + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: t.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            'Upload a record',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'PDF, JPG, PNG or DICOM · Max 10MB',
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Choose file',
                  variant: AppButtonVariant.outline,
                  icon: PhosphorIconsRegular.file,
                  onPressed: _uploading ? null : _pickFile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Pick image',
                  variant: AppButtonVariant.outline,
                  icon: PhosphorIconsRegular.image,
                  onPressed: _uploading ? null : _pickImage,
                ),
              ),
            ],
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_iconForName(_fileName!), size: 20, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink),
                    ),
                  ),
                  if (!_uploading)
                    InkWell(
                      onTap: () => setState(() {
                        _path = null;
                        _fileName = null;
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(PhosphorIconsRegular.x, size: 16, color: t.ink3),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Category',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reportCategories.map((c) {
              final selected = c == _category;
              return GestureDetector(
                onTap: _uploading ? null : () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.teal.withValues(alpha: dark ? 0.18 : 0.12)
                        : t.card,
                    borderRadius: BorderRadius.circular(999),
                    border: selected ? null : Border.all(color: t.line),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 13.4,
                      fontWeight: FontWeight.w600,
                      color: selected ? (dark ? AppColors.teal : AppColors.tealD) : t.ink2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_uploading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Uploading…', style: TextStyle(fontSize: 12, color: t.ink3)),
                Text(
                  '$_progress%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 5,
                backgroundColor: t.line,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppButton(
            label: 'Upload',
            icon: PhosphorIconsBold.uploadSimple,
            loading: _uploading,
            onPressed: _path == null ? null : _upload,
          ),
        ],
      ),
    );
  }
}
