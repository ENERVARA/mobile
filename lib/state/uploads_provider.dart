import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reports_provider.dart';

/// One in-flight generic document upload (ephemeral — the finished report moves
/// into [reportsProvider]). Ported from `uploadStore.ts`.
class PendingUpload {
  final String id;
  final String name;
  final String filePath;
  final String? category;
  final int progress; // 0–100
  final String status; // uploading | uploaded | error

  const PendingUpload({
    required this.id,
    required this.name,
    required this.filePath,
    this.category,
    this.progress = 0,
    this.status = 'uploading',
  });

  PendingUpload copyWith({int? progress, String? status}) => PendingUpload(
        id: id,
        name: name,
        filePath: filePath,
        category: category,
        progress: progress ?? this.progress,
        status: status ?? this.status,
      );
}

final uploadsProvider =
    StateNotifierProvider<UploadsController, List<PendingUpload>>((ref) => UploadsController(ref));

class UploadsController extends StateNotifier<List<PendingUpload>> {
  UploadsController(this._ref) : super(const []);

  final Ref _ref;

  String addFile(String filePath, String name, {String? category}) {
    final id = 'upload-${DateTime.now().microsecondsSinceEpoch}';
    state = [
      ...state,
      PendingUpload(id: id, name: name, filePath: filePath, category: category),
    ];
    _run(id);
    return id;
  }

  void retry(String id) {
    final idx = state.indexWhere((u) => u.id == id);
    if (idx < 0) return;
    state = [
      for (final u in state) u.id == id ? u.copyWith(progress: 0, status: 'uploading') : u,
    ];
    _run(id);
  }

  void remove(String id) => state = state.where((u) => u.id != id).toList();

  Future<void> _run(String id) async {
    final u = state.where((x) => x.id == id).firstOrNull;
    if (u == null) return;
    try {
      final report = await _ref.read(reportsServiceProvider).upload(
            u.filePath,
            fileName: u.name,
            category: u.category,
            onProgress: (p) {
              if (!mounted) return;
              state = [for (final x in state) x.id == id ? x.copyWith(progress: p) : x];
            },
          );
      _ref.read(reportsProvider.notifier).addReport(report);
      if (!mounted) return;
      state = [
        for (final x in state) x.id == id ? x.copyWith(progress: 100, status: 'uploaded') : x,
      ];
      // Brief "Uploaded" flash, then settle — the real report now lives in
      // reportsProvider, so this ephemeral entry is no longer needed.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) state = state.where((x) => x.id != id).toList();
      });
    } catch (_) {
      if (mounted) {
        state = [for (final x in state) x.id == id ? x.copyWith(status: 'error') : x];
      }
    }
  }
}
