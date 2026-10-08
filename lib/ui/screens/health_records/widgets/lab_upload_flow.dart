import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/accent.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/lab_report.dart';
import '../../../../state/lab_reports_provider.dart';
import '../../../widgets/app_modal.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';
import '../../reports/widgets/lab_result_row.dart';

enum LabFlowOutcome { closed, saved, chooseAnother, cancel }

class LabFlowResult {
  final LabFlowOutcome outcome;
  final String? reportId;
  const LabFlowResult(this.outcome, [this.reportId]);
}

const _phaseTitle = <LabUploadPhase, String>{
  LabUploadPhase.idle: 'Scan new lab report',
  LabUploadPhase.validating: 'Checking your file',
  LabUploadPhase.uploading: 'Uploading',
  LabUploadPhase.processing: 'Reading your report',
  LabUploadPhase.review: 'Review extracted values',
  LabUploadPhase.saving: 'Saving',
  LabUploadPhase.error: 'Something went wrong',
};

/// The upload → process → review → save flow. Ported from `LabUploadModal.tsx`.
///
/// A dedicated frame rather than the shared one: the review step needs a wide,
/// scrollable body (`max-w-[720px] rounded-[20px] border bg-card p-6`, 45% scrim,
/// 2px blur). All state lives in `labReportsProvider`, so closing and reopening
/// mid-flow cannot desynchronise the UI from the in-flight request.
Future<LabFlowResult> showLabUploadModal(BuildContext context) async {
  final res = await showAppModal<LabFlowResult>(
    context,
    maxWidth: 720,
    padding: const EdgeInsets.all(24),
    radius: 20,
    bordered: true,
    scrim: 0.45,
    blur: 2,
    showClose: false,
    dismissible: false,
    onDismissRequest: () {
      // Handled inside the body (busy phases refuse to dismiss).
      _bodyDismiss?.call();
    },
    builder: (_) => const _LabUploadBody(),
  );
  _bodyDismiss = null;
  return res ?? const LabFlowResult(LabFlowOutcome.closed);
}

/// The body registers its dismiss handler here so the frame's backdrop / back
/// press can reuse the same "refuse while busy" rule.
VoidCallback? _bodyDismiss;

class _LabUploadBody extends ConsumerStatefulWidget {
  const _LabUploadBody();

  @override
  ConsumerState<_LabUploadBody> createState() => _LabUploadBodyState();
}

class _LabUploadBodyState extends ConsumerState<_LabUploadBody> {
  @override
  void initState() {
    super.initState();
    _bodyDismiss = _handleDismiss;
  }

  @override
  void dispose() {
    if (_bodyDismiss == _handleDismiss) _bodyDismiss = null;
    super.dispose();
  }

  bool get _busy {
    final p = ref.read(labReportsProvider).phase;
    return p == LabUploadPhase.uploading ||
        p == LabUploadPhase.processing ||
        p == LabUploadPhase.saving;
  }

  // Escape/backdrop closes, except mid-transfer where it would silently discard work.
  void _handleDismiss() {
    if (_busy) return;
    _close();
  }

  void _close([LabFlowResult? result]) {
    ref.read(labReportsProvider.notifier).closeUpload();
    if (mounted) Navigator.of(context).pop(result ?? const LabFlowResult(LabFlowOutcome.closed));
  }

  Future<void> _save() async {
    final saved = await ref.read(labReportsProvider.notifier).saveDraft();
    if (saved != null) {
      AppMessenger.success('Report added to your Health Records');
      _close(LabFlowResult(LabFlowOutcome.saved, saved.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = ref.watch(labReportsProvider);
    final phase = s.phase;
    final busy = phase == LabUploadPhase.uploading ||
        phase == LabUploadPhase.processing ||
        phase == LabUploadPhase.saving;
    final notifier = ref.read(labReportsProvider.notifier);

    Widget body;
    switch (phase) {
      case LabUploadPhase.idle:
        body = const SizedBox.shrink();
        break;
      case LabUploadPhase.validating:
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: _CenterSpinner(label: 'Checking the file…'),
        );
        break;
      case LabUploadPhase.uploading:
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploading…',
                    style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w600, color: t.ink),
                  ),
                  Text('${s.progress}%', style: TextStyle(fontSize: 13.6, color: t.ink2)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 8,
                  color: t.soft,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (s.progress / 100).clamp(0.0, 1.0),
                    child: Container(color: AppColors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _TextAction(
                label: 'Cancel upload',
                onTap: () {
                  notifier.cancelUpload();
                  if (mounted) Navigator.of(context).pop(const LabFlowResult(LabFlowOutcome.cancel));
                },
              ),
            ],
          ),
        );
        break;
      case LabUploadPhase.processing:
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              const AppSpinner(size: 32),
              const SizedBox(height: 16),
              Text(
                'Reading your report…',
                style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w600, color: t.ink),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Text(
                  'We are extracting the values and reference ranges printed on your document. This usually takes a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.44, height: 1.5, color: t.ink2),
                ),
              ),
              const SizedBox(height: 20),
              _TextAction(
                label: 'Cancel',
                onTap: () {
                  notifier.cancelUpload();
                  if (mounted) Navigator.of(context).pop(const LabFlowResult(LabFlowOutcome.cancel));
                },
              ),
            ],
          ),
        );
        break;
      case LabUploadPhase.error:
        final err = s.error;
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (err != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(PhosphorIconsFill.warningCircle, size: 19.2, color: AppColors.coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              err.message,
                              style: TextStyle(
                                fontSize: 14.72,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: t.ink,
                              ),
                            ),
                            if (!err.retryable)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Choose a different file to continue.',
                                  style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (err?.retryable ?? false)
                    WebButton(
                      label: 'Try again',
                      icon: PhosphorIconsRegular.arrowClockwise,
                      onTap: notifier.retryUpload,
                    ),
                  WebButton(
                    label: 'Choose another file',
                    variant: WebButtonVariant.ghost,
                    onTap: () {
                      notifier.cancelUpload();
                      Navigator.of(context).pop(const LabFlowResult(LabFlowOutcome.chooseAnother));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
        break;
      case LabUploadPhase.review:
      case LabUploadPhase.saving:
        final draft = s.draft;
        body = draft == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (MediaQuery.sizeOf(context).height * 0.6).clamp(0, 540),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 4),
                      child: LabReviewPanels(
                        draft: draft,
                        onResultChange: (id, v) => notifier.updateDraftResult(id, v),
                        onMetaChange: ({reportType, reportDate, clearReportDate = false}) =>
                            notifier.updateDraftMeta(
                          reportType: reportType,
                          reportDate: reportDate,
                          clearReportDate: clearReportDate,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WebButton(
                          label: phase == LabUploadPhase.saving ? 'Saving…' : 'Save report',
                          icon: PhosphorIconsRegular.check,
                          onTap: phase == LabUploadPhase.saving ? null : _save,
                        ),
                        WebButton(
                          label: 'Discard',
                          variant: WebButtonVariant.ghost,
                          onTap: phase == LabUploadPhase.saving ? null : _close,
                        ),
                        if (draft.metadata.sizeBytes != null)
                          Text(
                            Formatters.fileSize(draft.metadata.sizeBytes!),
                            style: TextStyle(fontSize: 12.48, color: t.ink3),
                          ),
                      ],
                    ),
                  ),
                ],
              );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phaseTitle[phase] ?? '',
                      style: TextStyle(
                        fontSize: 18.4,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.368,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    if (s.fileName.isNotEmpty && phase != LabUploadPhase.idle)
                      Text(
                        s.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: busy ? 0.4 : 1,
                child: GestureDetector(
                  onTap: busy ? null : _close,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(PhosphorIconsRegular.x, size: 16, color: t.ink3),
                  ),
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }
}

class _CenterSpinner extends StatelessWidget {
  final String label;
  const _CenterSpinner({required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const AppSpinner(size: 32),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(fontSize: 14.4, color: context.tokens.ink2)),
        ],
      );
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.6,
              fontWeight: FontWeight.w600,
              color: context.tokens.ink2,
            ),
          ),
        ),
      );
}

String _toDateOnly(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The review step: what we read, before it is saved. Ported from
/// `LabReviewPanels.tsx`.
///
/// Values are editable because extraction is imperfect and the user is holding
/// the source document. Flags are NOT editable — they are recomputed on the
/// server when the report is saved, so nothing here can mark a marker as being in
/// range.
class LabReviewPanels extends StatelessWidget {
  final LabReport draft;
  final void Function(String resultId, double? value) onResultChange;
  final void Function({String? reportType, String? reportDate, bool clearReportDate}) onMetaChange;

  const LabReviewPanels({
    super.key,
    required this.draft,
    required this.onResultChange,
    required this.onMetaChange,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(draft.reportDate ?? '')?.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked != null) {
      // new Date('YYYY-MM-DD').toISOString() — midnight UTC.
      final utc = DateTime.utc(picked.year, picked.month, picked.day);
      onMetaChange(reportDate: utc.toIso8601String());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateText = _toDateOnly(draft.reportDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(PhosphorIconsFill.info, size: 16, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Check these against your original report and correct anything we misread. Flags show whether a value sits outside the reference range printed on your document — they are not a medical assessment.',
                  style: TextStyle(fontSize: 13.12, height: 1.625, color: t.ink2),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel('Report type'),
              const SizedBox(height: 6),
              WebSelect<String>(
                value: draft.reportType,
                options: [
                  for (final type in kLabReportTypes)
                    (
                      value: type,
                      label: type == 'OTHER'
                          ? labReportTypeLabel(type)
                          : '$type — ${labReportTypeLabel(type)}',
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onMetaChange(reportType: v);
                },
              ),
              const SizedBox(height: 12),
              _FieldLabel('Report date'),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickDate(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.line, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateText.isEmpty ? 'yyyy-mm-dd' : dateText,
                          style: TextStyle(
                            fontSize: 14.08,
                            color: dateText.isEmpty ? t.ink3 : t.ink,
                          ),
                        ),
                      ),
                      Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: t.ink3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (draft.panels.isEmpty)
          DashedEmpty(
            title: 'No values were read from this document.',
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            titleSize: 14.08,
          )
        else
          for (final panel in draft.panels)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const AccentIconBox(
                          icon: PhosphorIconsFill.flask,
                          accent: Accent.teal,
                          size: 28,
                          radius: 8,
                          iconSize: 13.6,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            panel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.2,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${panel.results.length} marker${panel.results.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12.48, color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.line),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < panel.results.length; i++)
                          LabResultRow(
                            result: panel.results[i],
                            first: i == 0,
                            editable: true,
                            onValueChange: onResultChange,
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12.8,
          fontWeight: FontWeight.w600,
          color: context.tokens.ink2,
        ),
      );
}
