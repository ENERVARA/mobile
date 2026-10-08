import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/models/prescription.dart';
import '../../../state/nova_ui_provider.dart';
import '../../../state/prescriptions_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import 'widgets/medication_card.dart';

/// A saved prescription: the transcription summary, the medicines, and the
/// hand-offs (discuss with Nova, view the original). Ported from
/// `PrescriptionDetailPage.tsx`.
class PrescriptionDetailPage extends ConsumerStatefulWidget {
  final String id;
  const PrescriptionDetailPage({super.key, required this.id});

  @override
  ConsumerState<PrescriptionDetailPage> createState() => _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState extends ConsumerState<PrescriptionDetailPage> {
  Prescription? _prescription;
  bool _loaded = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(prescriptionsServiceProvider).getPrescription(widget.id);
      if (mounted) setState(() => _prescription = p);
    } catch (_) {
      if (mounted) setState(() => _prescription = null);
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _viewOriginal() async {
    setState(() => _opening = true);
    try {
      // A short-lived URL minted on demand — never a stored or public link.
      final ticket = await ref.read(prescriptionsServiceProvider).getDownloadUrl(widget.id);
      await launchUrl(Uri.parse(ticket.url), mode: LaunchMode.externalApplication);
    } catch (_) {
      AppMessenger.error('We couldn’t open the original document right now.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      message: 'Delete this prescription? The original document is removed too.',
    );
    if (!ok) return;
    await ref.read(prescriptionsProvider.notifier).remove(widget.id);
    if (mounted) context.go('/health-records');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final p = _prescription;

    if (!_loaded) {
      return const Center(child: AppSpinner(size: 40));
    }

    if (p == null) {
      return ShellPage(
        children: [
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
                  'Prescription not found',
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
          ),
        ],
      );
    }

    final summary = p.summary;
    final metadata = p.metadata;
    final prescribed = Formatters.tryParse(p.prescribedDate);
    final created = Formatters.tryParse(p.createdAt);
    final sub = [
      metadata.clinicName,
      prescribed != null ? 'Prescribed ${Formatters.dateFull(prescribed)}' : null,
    ].where((x) => x != null && x.isNotEmpty).join(' · ');
    final speciality = specialityName(p.suggestedSpecialitySlug);
    final danger = dark ? const Color(0xFFFF8968) : const Color(0xFFC1441F);

    Widget tile(int value, String label, {Color? tone}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18.4,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: tone ?? t.ink,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11.52, height: 1.5, color: t.ink2)),
              ],
            ),
          ),
        );

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
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x1F6D5BD0),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        PhosphorIconsFill.prescription,
                        size: 20.8,
                        color: dark ? const Color(0xFFA99BF5) : const Color(0xFF6D5BD0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.prescriberName ?? 'Prescription',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19.2,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: t.ink,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(sub, style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink3)),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Uploaded ${created != null ? Formatters.dateFull(created) : ''}',
                              style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (metadata.indicationNotes != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Noted on the prescription: ${metadata.indicationNotes}',
                    style: TextStyle(fontSize: 13.12, height: 1.625, color: t.ink2),
                  ),
                ),
              // grid-cols-4 max-md:grid-cols-2 gap-2
              Column(
                children: [
                  Row(
                    children: [
                      tile(summary.medicationCount, 'Medicines'),
                      const SizedBox(width: 8),
                      tile(summary.clearCount, 'Read clearly'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      tile(summary.partialCount, 'Incomplete'),
                      const SizedBox(width: 8),
                      tile(
                        summary.needsReviewCount,
                        'Needs review',
                        tone: summary.needsReviewCount > 0 ? danger : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  LegacyButton(
                    label: 'Discuss with $speciality',
                    icon: PhosphorIconsFill.chatCircleDots,
                    onPressed: () => ref
                        .read(novaUiProvider.notifier)
                        .openWithDraft(p.suggestedSpecialitySlug, buildPrescriptionChatMessage(p)),
                  ),
                  LegacyButton(
                    label: 'View original',
                    icon: PhosphorIconsRegular.fileMagnifyingGlass,
                    variant: LegacyButtonVariant.secondary,
                    isLoading: _opening,
                    onPressed: _opening ? null : _viewOriginal,
                  ),
                  LegacyButton(
                    label: 'Delete',
                    icon: PhosphorIconsRegular.trash,
                    variant: LegacyButtonVariant.secondary,
                    onPressed: _delete,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Medicines',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
          ),
        ),
        if (p.medications.isEmpty)
          DashedBox(
            radius: 14,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No medicines were found on this document.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < p.medications.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                MedicationCard(medication: p.medications[i]),
              ],
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            "This is a transcription of what was printed on your prescription, not medical advice. Always compare it with the original document and follow your prescriber's instructions.",
            style: TextStyle(fontSize: 12.16, height: 1.625, color: t.ink3),
          ),
        ),
      ],
    );
  }
}
