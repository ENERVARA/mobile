import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../data/models/prescription.dart';
import '../../../../state/nova_ui_provider.dart';
import '../../../../state/prescriptions_provider.dart';
import '../../../widgets/app_modal.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';
import '../../prescriptions/widgets/medication_card.dart';

enum RxFlowOutcome { closed, chooseAnother, cancel }

/// Scan → upload → process → review → save, in one modal. Ported from
/// `PrescriptionUploadModal.tsx`.
///
/// The phase machine lives in the provider; this only renders the current phase
/// and offers the action that belongs to it. Cancel is available during transfer
/// and analysis, and a failure offers retry only when retrying could plausibly
/// succeed.
Future<RxFlowOutcome> showPrescriptionUploadModal(BuildContext context) async {
  final res = await showAppModal<RxFlowOutcome>(
    context,
    maxWidth: 512,
    dismissible: false,
    showClose: false,
    onDismissRequest: () => _dismiss?.call(),
    builder: (_) => const _PrescriptionBody(),
  );
  _dismiss = null;
  return res ?? RxFlowOutcome.closed;
}

VoidCallback? _dismiss;

class _PrescriptionBody extends ConsumerStatefulWidget {
  const _PrescriptionBody();

  @override
  ConsumerState<_PrescriptionBody> createState() => _PrescriptionBodyState();
}

class _PrescriptionBodyState extends ConsumerState<_PrescriptionBody> {
  Prescription? _saved;

  @override
  void initState() {
    super.initState();
    _dismiss = _onDismissRequest;
  }

  @override
  void dispose() {
    if (_dismiss == _onDismissRequest) _dismiss = null;
    super.dispose();
  }

  bool get _busy {
    final p = ref.read(prescriptionsProvider).phase;
    return p == RxUploadPhase.uploading ||
        p == RxUploadPhase.processing ||
        p == RxUploadPhase.validating;
  }

  void _onDismissRequest() {
    if (_busy) {
      _cancelBusy();
    } else {
      _close();
    }
  }

  void _close([RxFlowOutcome outcome = RxFlowOutcome.closed]) {
    ref.read(prescriptionsProvider.notifier).reset();
    _saved = null;
    if (mounted) Navigator.of(context).pop(outcome);
  }

  void _cancelBusy() {
    ref.read(prescriptionsProvider.notifier).cancel();
    if (mounted) Navigator.of(context).pop(RxFlowOutcome.cancel);
  }

  Future<void> _save() async {
    final result = await ref.read(prescriptionsProvider.notifier).save();
    if (result != null && mounted) {
      setState(() => _saved = result);
      AppMessenger.success('Prescription saved');
    }
  }

  void _discuss(Prescription p) {
    // The summary goes into the composer, NOT straight to the assistant — the
    // user sees exactly what is about to be shared and can edit it first.
    ref
        .read(novaUiProvider.notifier)
        .openWithDraft(p.suggestedSpecialitySlug, buildPrescriptionChatMessage(p));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final s = ref.watch(prescriptionsProvider);
    final notifier = ref.read(prescriptionsProvider.notifier);
    final phase = s.phase;
    final saved = _saved;

    final busy = phase == RxUploadPhase.uploading ||
        phase == RxUploadPhase.processing ||
        phase == RxUploadPhase.validating;

    Widget body;
    if (saved != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.checkCircle, size: 27.2, color: AppColors.teal),
            ),
            Text(
              '${saved.summary.medicationCount} ${saved.summary.medicationCount == 1 ? 'medicine' : 'medicines'} saved',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(
                saved.suggestedSpecialityReason ??
                    'You can talk this through with ${specialityName(saved.suggestedSpecialitySlug)}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.76, height: 1.625, color: t.ink2),
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LegacyButton(
                    label: 'Discuss with ${specialityName(saved.suggestedSpecialitySlug)}',
                    icon: PhosphorIconsFill.chatCircleDots,
                    fullWidth: true,
                    onPressed: () => _discuss(saved),
                  ),
                  const SizedBox(height: 10),
                  LegacyButton(
                    label: 'Done',
                    variant: LegacyButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (busy) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            if (phase == RxUploadPhase.uploading) ...[
              const Icon(PhosphorIconsRegular.cloudArrowUp, size: 32, color: AppColors.teal),
              const SizedBox(height: 12),
              Text(
                'Uploading… ${s.progress}%',
                style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 6,
                    color: t.soft,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (s.progress / 100).clamp(0.0, 1.0),
                      child: Container(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const AppSpinner(size: 40),
              const SizedBox(height: 16),
              Text(
                phase == RxUploadPhase.validating
                    ? 'Checking the file…'
                    : 'Reading your prescription…',
                style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'This usually takes a few seconds.',
                style: TextStyle(fontSize: 13.12, color: t.ink2),
              ),
            ],
            const SizedBox(height: 24),
            LegacyButton(
              label: 'Cancel',
              variant: LegacyButtonVariant.secondary,
              onPressed: _cancelBusy,
            ),
          ],
        ),
      );
    } else if (phase == RxUploadPhase.error && s.error != null) {
      final err = s.error!;
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(PhosphorIconsFill.warningCircle, size: 32, color: AppColors.coral),
            const SizedBox(height: 12),
            Text(
              "We couldn't read that",
              style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w600, color: t.ink),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(
                err.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (err.retryable)
                  LegacyButton(label: 'Try again', onPressed: notifier.retry),
                LegacyButton(
                  label: 'Choose another file',
                  variant: LegacyButtonVariant.secondary,
                  onPressed: () {
                    notifier.reset();
                    Navigator.of(context).pop(RxFlowOutcome.chooseAnother);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    } else if ((phase == RxUploadPhase.review || phase == RxUploadPhase.saving) && s.draft != null) {
      final draft = s.draft!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Check these against your prescription before saving. '),
                      if (draft.summary.needsReviewCount > 0)
                        TextSpan(
                          text:
                              '${draft.summary.needsReviewCount} ${draft.summary.needsReviewCount == 1 ? 'line was' : 'lines were'} hard to read.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
                        ),
                    ],
                  ),
                  style: TextStyle(fontSize: 13.44, height: 1.625, color: t.ink2),
                ),
                if ((draft.prescriberName ?? '').isNotEmpty || (draft.clinicName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [draft.prescriberName, draft.clinicName]
                          .where((x) => x != null && x.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(fontSize: 12.48, color: t.ink3),
                    ),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.46),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                children: [
                  for (final m in draft.medications) ...[
                    MedicationCard(
                      key: ValueKey(m.id),
                      medication: m,
                      editable: true,
                      onEdit: (edit) => notifier.editMedication(m.id, edit),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (draft.medications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "We couldn't find any medicines on this document. You can still save it and open the original.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LegacyButton(
                label: 'Discard',
                variant: LegacyButtonVariant.secondary,
                onPressed: phase == RxUploadPhase.saving ? null : _close,
              ),
              const SizedBox(width: 10),
              LegacyButton(
                label: 'Save prescription',
                isLoading: phase == RxUploadPhase.saving,
                onPressed: phase == RxUploadPhase.saving ? null : _save,
              ),
            ],
          ),
        ],
      );
    } else {
      body = const SizedBox(height: 8);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                saved != null ? 'Prescription saved' : 'Scan a prescription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: dark ? const Color(0xFFF4F4F5) : const Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ModalCloseChip(onTap: _onDismissRequest),
          ],
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}
