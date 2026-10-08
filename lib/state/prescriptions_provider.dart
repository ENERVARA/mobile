import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/app_messenger.dart';
import '../data/models/prescription.dart';
import '../data/services/prescriptions_service.dart';
import '../data/services/upload_support.dart';

final prescriptionsServiceProvider = Provider((ref) => const PrescriptionsService());

final prescriptionsProvider =
    StateNotifierProvider<PrescriptionsController, PrescriptionsState>(
  (ref) => PrescriptionsController(ref),
);

/// The upload flow is an explicit phase machine rather than a set of booleans.
/// Upload → process → review is a genuine sequence with a cancel and a retry at
/// different points, and booleans make illegal combinations representable.
enum RxUploadPhase { idle, validating, uploading, processing, review, saving, error }

class PrescriptionsListQuery {
  final String search;
  final String status; // ALL | SAVED | READY_FOR_REVIEW | FAILED
  final String sort;
  const PrescriptionsListQuery({this.search = '', this.status = 'ALL', this.sort = 'DATE_DESC'});

  PrescriptionsListQuery copyWith({String? search, String? status, String? sort}) =>
      PrescriptionsListQuery(
        search: search ?? this.search,
        status: status ?? this.status,
        sort: sort ?? this.sort,
      );
}

class PrescriptionsState {
  final List<PrescriptionListItem> items;
  final bool isLoaded;
  final bool isLoading;
  final PrescriptionsListQuery query;

  final RxUploadPhase phase;
  final int progress;
  final UploadError? error;

  /// The prescription being uploaded/reviewed. Null outside the flow.
  final Prescription? draft;

  const PrescriptionsState({
    this.items = const [],
    this.isLoaded = false,
    this.isLoading = false,
    this.query = const PrescriptionsListQuery(),
    this.phase = RxUploadPhase.idle,
    this.progress = 0,
    this.error,
    this.draft,
  });

  PrescriptionsState copyWith({
    List<PrescriptionListItem>? items,
    bool? isLoaded,
    bool? isLoading,
    PrescriptionsListQuery? query,
    RxUploadPhase? phase,
    int? progress,
    UploadError? error,
    bool clearError = false,
    Prescription? draft,
    bool clearDraft = false,
  }) =>
      PrescriptionsState(
        items: items ?? this.items,
        isLoaded: isLoaded ?? this.isLoaded,
        isLoading: isLoading ?? this.isLoading,
        query: query ?? this.query,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
        draft: clearDraft ? null : (draft ?? this.draft),
      );
}

/// A duplicate or an oversized file will fail identically on retry — offering
/// one would just waste the user's time.
const _terminalCodes = {
  'DUPLICATE_UPLOAD',
  'FILE_TOO_LARGE',
  'FILE_TOO_SMALL',
  'UNSUPPORTED_FILE_TYPE',
  'PRESCRIPTION_LIMIT_REACHED',
};

/// Prescription state — ported from `prescriptionsStore.ts`. Not persisted: the
/// backend is the source of truth and the list is refetched on mount.
class PrescriptionsController extends StateNotifier<PrescriptionsState> {
  PrescriptionsController(this._ref) : super(const PrescriptionsState());

  final Ref _ref;
  PrescriptionsService get _svc => _ref.read(prescriptionsServiceProvider);

  CancelToken? _cancelToken;
  String? _pendingPath;
  String? _pendingName;
  String? _pendingMime;

  Future<void> load([PrescriptionsListQuery? patch]) async {
    final query = patch ?? state.query;
    state = state.copyWith(isLoading: true, query: query);
    try {
      final items = await _svc.listPrescriptions(
        search: query.search,
        status: query.status,
        sort: query.sort,
      );
      if (mounted) state = state.copyWith(items: items, isLoaded: true, isLoading: false);
    } catch (_) {
      // The API client has already surfaced the message.
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void setQuery(PrescriptionsListQuery next) {
    state = state.copyWith(query: next);
    load(next);
  }

  Future<void> startUpload(String filePath, String fileName) async {
    _pendingPath = filePath;
    _pendingName = fileName;
    state = state.copyWith(
      phase: RxUploadPhase.validating,
      clearError: true,
      progress: 0,
      clearDraft: true,
    );

    // Client-side validation is a fast, clear failure — the server re-checks
    // everything regardless, so this is convenience, not trust.
    final check = await validateLabFile(filePath, fileName: fileName);
    if (!mounted) return;
    if (!check.ok) {
      state = state.copyWith(
        phase: RxUploadPhase.error,
        error: UploadError(code: check.code, message: check.message!, retryable: false),
      );
      return;
    }
    _pendingMime = check.mimeType;

    final cancel = _cancelToken = CancelToken();
    try {
      final size = await File(filePath).length();
      final ticket = await _svc.createUpload(
        fileName: fileName,
        mimeType: _pendingMime ?? 'application/pdf',
        sizeBytes: size,
      );

      state = state.copyWith(phase: RxUploadPhase.uploading, progress: 0);
      await _svc.uploadFile(
        ticket,
        filePath,
        cancelToken: cancel,
        onProgress: (p) {
          if (mounted) state = state.copyWith(progress: p);
        },
      );

      await _svc.completeUpload(ticket.reportId);

      state = state.copyWith(phase: RxUploadPhase.processing, progress: 100);
      final analysed = await _svc.processPrescription(ticket.reportId, cancelToken: cancel);

      if (mounted) state = state.copyWith(phase: RxUploadPhase.review, draft: analysed);
    } catch (e) {
      if (cancel.isCancelled) {
        if (mounted) {
          state = state.copyWith(phase: RxUploadPhase.idle, progress: 0, clearError: true);
        }
        return;
      }
      if (mounted) {
        state = state.copyWith(
          phase: RxUploadPhase.error,
          error: UploadError.from(
            e,
            fallback: 'Something went wrong. Please try again.',
            terminal: _terminalCodes,
          ),
        );
      }
    } finally {
      _cancelToken = null;
    }
  }

  Future<void> retry() async {
    final path = _pendingPath;
    final name = _pendingName;
    if (path == null || name == null) {
      state = state.copyWith(phase: RxUploadPhase.idle, clearError: true);
      return;
    }
    await startUpload(path, name);
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(
      phase: RxUploadPhase.idle,
      progress: 0,
      clearError: true,
      clearDraft: true,
    );
  }

  /// Applies review edits locally; nothing is sent until [save].
  void editMedication(String id, Medication Function(Medication) edit) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.withMedications([
        for (final m in draft.medications) m.id == id ? edit(m) : m,
      ]),
    );
  }

  Future<Prescription?> save() async {
    final draft = state.draft;
    if (draft == null) return null;
    state = state.copyWith(phase: RxUploadPhase.saving);
    try {
      final saved = await _svc.savePrescription(draft.id, draft.toSavePayload());
      // Refresh the list so the new record appears without a manual reload.
      load();
      if (mounted) {
        state = state.copyWith(phase: RxUploadPhase.idle, draft: saved, progress: 0);
      }
      return saved;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          phase: RxUploadPhase.error,
          error: UploadError.from(
            e,
            fallback: 'Something went wrong. Please try again.',
            terminal: _terminalCodes,
          ),
        );
      }
      return null;
    }
  }

  void reset() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(
      phase: RxUploadPhase.idle,
      progress: 0,
      clearError: true,
      clearDraft: true,
    );
  }

  Future<void> remove(String id) async {
    try {
      await _svc.deletePrescription(id);
      state = state.copyWith(items: state.items.where((p) => p.id != id).toList());
      AppMessenger.success('Prescription deleted');
    } catch (_) {
      /* toasted by the API client */
    }
  }
}
