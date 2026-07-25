import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/report.dart';
import '../data/services/reports_service.dart';

final reportsServiceProvider = Provider((ref) => const ReportsService());

final reportsProvider =
    StateNotifierProvider<ReportsController, ReportsState>((ref) => ReportsController(ref));

class ReportsState {
  final List<Report> reports;
  final bool isLoaded;
  final bool isLoading;
  const ReportsState({this.reports = const [], this.isLoaded = false, this.isLoading = false});

  ReportsState copyWith({List<Report>? reports, bool? isLoaded, bool? isLoading}) => ReportsState(
        reports: reports ?? this.reports,
        isLoaded: isLoaded ?? this.isLoaded,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(this._ref) : super(const ReportsState());

  final Ref _ref;
  ReportsService get _service => _ref.read(reportsServiceProvider);

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final reports = await _service.list();
      state = state.copyWith(reports: reports, isLoaded: true, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void addReport(Report report) {
    state = state.copyWith(reports: [report, ...state.reports]);
  }

  Future<void> removeReport(String id) async {
    await _service.delete(id);
    state = state.copyWith(reports: state.reports.where((r) => r.id != id).toList());
  }

  /// Uploads a picked file with live progress via [onProgress], pushing the
  /// finished report into state on success.
  Future<void> upload(
    String filePath, {
    String? fileName,
    String? category,
    void Function(int percent)? onProgress,
  }) async {
    final report = await _service.upload(
      filePath,
      fileName: fileName,
      category: category,
      onProgress: onProgress,
    );
    addReport(report);
  }
}
