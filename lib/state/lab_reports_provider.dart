import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/lab_report.dart';
import '../data/services/lab_reports_service.dart';
import '../data/services/upload_support.dart';

final labReportsServiceProvider = Provider((ref) => const LabReportsService());

final labReportsProvider =
    StateNotifierProvider<LabReportsController, LabReportsState>((ref) => LabReportsController(ref));

/// Where the upload flow currently is. Drives the whole upload sheet.
enum LabUploadPhase { idle, validating, uploading, processing, review, saving, error }

/// The step to resume from after a failure, so Retry never re-does work.
enum _ResumeStep { create, upload, complete, process }

class LabListQuery {
  final String search;
  final String reportType; // ALL | CBC | …
  final String status; // ALL | SAVED | …
  final String sort;
  const LabListQuery({
    this.search = '',
    this.reportType = 'ALL',
    this.status = 'ALL',
    this.sort = 'DATE_DESC',
  });

  LabListQuery copyWith({String? search, String? reportType, String? status, String? sort}) =>
      LabListQuery(
        search: search ?? this.search,
        reportType: reportType ?? this.reportType,
        status: status ?? this.status,
        sort: sort ?? this.sort,
      );

  bool get hasFilters => search.trim().isNotEmpty || reportType != 'ALL' || status != 'ALL';
}

class LabReportsState {
  final List<LabReportListItem> reports;
  final bool isLoaded;
  final bool isLoading;
  final LabListQuery query;

  final LabUploadPhase phase;
  final int progress;
  final String fileName;
  final String? reportId;
  final LabReport? draft;
  final UploadError? error;

  const LabReportsState({
    this.reports = const [],
    this.isLoaded = false,
    this.isLoading = false,
    this.query = const LabListQuery(),
    this.phase = LabUploadPhase.idle,
    this.progress = 0,
    this.fileName = '',
    this.reportId,
    this.draft,
    this.error,
  });

  LabReportsState copyWith({
    List<LabReportListItem>? reports,
    bool? isLoaded,
    bool? isLoading,
    LabListQuery? query,
    LabUploadPhase? phase,
    int? progress,
    String? fileName,
    String? reportId,
    bool clearReportId = false,
    LabReport? draft,
    bool clearDraft = false,
    UploadError? error,
    bool clearError = false,
  }) =>
      LabReportsState(
        reports: reports ?? this.reports,
        isLoaded: isLoaded ?? this.isLoaded,
        isLoading: isLoading ?? this.isLoading,
        query: query ?? this.query,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        fileName: fileName ?? this.fileName,
        reportId: clearReportId ? null : (reportId ?? this.reportId),
        draft: clearDraft ? null : (draft ?? this.draft),
        error: clearError ? null : (error ?? this.error),
      );
}

/// Lab Results state — ported from `labReportsStore.ts`. Not persisted: the
/// backend is the source of truth. It owns two things: the list (with its
/// server-side query) and the upload flow's state machine.
class LabReportsController extends StateNotifier<LabReportsState> {
  LabReportsController(this._ref) : super(const LabReportsState());

  final Ref _ref;
  LabReportsService get _svc => _ref.read(labReportsServiceProvider);

  // Out-of-state handles for the in-flight upload (mutable, non-render state).
  String? _activeFilePath;
  String? _activeMime;
  UploadTicket? _activeTicket;
  _ResumeStep _resumeStep = _ResumeStep.create;
  CancelToken? _cancelToken;

  /// Guards against a stale request overwriting a newer one's result.
  int _runToken = 0;

  // ── List ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final q = state.query;
      final reports = await _svc.listReports(
        search: q.search,
        reportType: q.reportType,
        status: q.status,
        sort: q.sort,
      );
      if (!mounted) return;
      state = state.copyWith(reports: reports, isLoaded: true, isLoading: false);
    } catch (_) {
      // The API client already surfaced a toast.
      if (mounted) state = state.copyWith(isLoading: false, isLoaded: true);
    }
  }

  void setQuery(LabListQuery next) {
    state = state.copyWith(query: next);
    load();
  }

  Future<void> removeReport(String id) async {
    await _svc.deleteReport(id);
    state = state.copyWith(reports: state.reports.where((r) => r.id != id).toList());
  }

  // ── Upload flow ───────────────────────────────────────────────────────────

  Future<void> startUpload(String filePath, String fileName) async {
    _activeFilePath = filePath;
    _activeTicket = null;
    _resumeStep = _ResumeStep.create;
    state = state.copyWith(
      phase: LabUploadPhase.validating,
      progress: 0,
      fileName: fileName,
      clearReportId: true,
      clearDraft: true,
      clearError: true,
    );

    // Client-side validation is UX only; the server re-checks everything.
    final known = state.reports.map((r) => (name: r.originalFileName, size: null as int?)).toList();
    final check = await validateLabFile(filePath, fileName: fileName, existing: known);
    if (!mounted) return;
    if (!check.ok) {
      state = state.copyWith(
        phase: LabUploadPhase.error,
        error: UploadError(code: check.code, message: check.message!, retryable: false),
      );
      return;
    }
    _activeMime = check.mimeType;
    await _runUploadFlow();
  }

  Future<void> retryUpload() async {
    if (_activeFilePath == null) return;
    state = state.copyWith(clearError: true);
    await _runUploadFlow();
  }

  void cancelUpload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _runToken += 1;
    state = state.copyWith(
      phase: LabUploadPhase.idle,
      progress: 0,
      fileName: '',
      clearReportId: true,
      clearDraft: true,
      clearError: true,
    );
  }

  void closeUpload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _activeFilePath = null;
    _activeTicket = null;
    _runToken += 1;
    state = state.copyWith(
      phase: LabUploadPhase.idle,
      progress: 0,
      fileName: '',
      clearReportId: true,
      clearDraft: true,
      clearError: true,
    );
  }

  // ── Review ────────────────────────────────────────────────────────────────

  void updateDraftResult(String resultId, double? value) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(
        panels: [
          for (final panel in draft.panels)
            panel.copyWith(results: [
              for (final r in panel.results)
                r.id == resultId ? r.copyWith(value: value, clearValue: value == null) : r,
            ]),
        ],
      ),
    );
  }

  void updateDraftMeta({String? reportType, String? reportDate, bool clearReportDate = false}) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(
        reportType: reportType,
        reportDate: reportDate,
        clearReportDate: clearReportDate,
      ),
    );
  }

  Future<LabReport?> saveDraft() async {
    final draft = state.draft;
    if (draft == null) return null;

    state = state.copyWith(phase: LabUploadPhase.saving, clearError: true);
    try {
      final saved = await _svc.saveReport(draft.id, draft.toSavePayload());
      if (!mounted) return saved;
      state = state.copyWith(draft: saved);
      // Refresh the list so the saved report appears in the Lab Results tab.
      await load();
      return saved;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          phase: LabUploadPhase.review,
          error: UploadError.from(e, fallback: 'Could not save this report'),
        );
      }
      return null;
    }
  }

  /// The upload → process pipeline. Each completed step advances
  /// [_resumeStep], so Retry after a network blip continues from the failure
  /// point instead of creating a second report.
  Future<void> _runUploadFlow() async {
    final path = _activeFilePath;
    if (path == null) return;
    final fileName = state.fileName;

    _cancelToken = CancelToken();
    final cancel = _cancelToken!;
    final token = ++_runToken;
    bool isStale() => token != _runToken || !mounted;

    try {
      if (_resumeStep == _ResumeStep.create) {
        state = state.copyWith(phase: LabUploadPhase.uploading, progress: 0);
        final size = await _fileSize(path);
        _activeTicket = await _svc.createUpload(
          fileName: fileName,
          mimeType: _activeMime ?? 'application/pdf',
          sizeBytes: size,
        );
        if (isStale()) return;
        state = state.copyWith(reportId: _activeTicket!.reportId);
        _resumeStep = _ResumeStep.upload;
      }

      if (_resumeStep == _ResumeStep.upload) {
        final ticket = _activeTicket;
        if (ticket == null) throw Exception('Upload was not initialised');
        state = state.copyWith(phase: LabUploadPhase.uploading);
        await _svc.putFile(
          ticket,
          path,
          cancelToken: cancel,
          onProgress: (p) {
            if (!isStale()) state = state.copyWith(progress: p);
          },
        );
        if (isStale()) return;
        _resumeStep = _ResumeStep.complete;
      }

      final reportId = state.reportId;
      if (reportId == null) throw Exception('Upload was not initialised');

      if (_resumeStep == _ResumeStep.complete) {
        state = state.copyWith(progress: 100);
        await _svc.completeUpload(reportId);
        if (isStale()) return;
        _resumeStep = _ResumeStep.process;
      }

      if (_resumeStep == _ResumeStep.process) {
        state = state.copyWith(phase: LabUploadPhase.processing);
        final draft = await _svc.processReport(reportId, cancelToken: cancel);
        if (isStale()) return;
        state = state.copyWith(phase: LabUploadPhase.review, draft: draft);
        _resumeStep = _ResumeStep.process;
      }
    } catch (e) {
      if (isStale()) return;
      // A cancellation is a user action, not an error — cancelUpload already
      // reset the state, so say nothing.
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = state.copyWith(
        phase: LabUploadPhase.error,
        error: UploadError.from(e, fallback: 'Something went wrong'),
      );
    } finally {
      if (token == _runToken) _cancelToken = null;
    }
  }

  static Future<int> _fileSize(String path) => File(path).length();
}
