import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/document_guess.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/health_records_provider.dart';
import '../../../state/lab_reports_provider.dart';
import '../../../state/prescriptions_provider.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/common.dart';
import 'widgets/lab_upload_flow.dart';
import 'widgets/prescription_upload_flow.dart';

/// One entry point for everything a patient brings from their healthcare.
/// Ported from `AddToMyHealthFlow.tsx`.
///
/// The patient never chooses "Prescription" vs "Lab Report" before capturing:
/// they scan or upload first, and only then confirm what it is — pre-filled with
/// our best guess when we have one ("We think this is a Lab report. Is that
/// correct?"). Lab reports and prescriptions then go through their extraction +
/// review step, so nothing extracted enters the record until the patient has
/// checked it.
///
/// Like the web, the steps are separate modals (type step → lab/prescription
/// read-and-review modal); the picked file survives between them so cancelling
/// mid-transfer lands back on the type step.
Future<void> showAddToMyHealthFlow(BuildContext context) async {
  // The router/providers that own the page launching the flow — the dialog
  // contexts sit above the shell, so navigation after a save goes through these.
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);
  final session = _Session();

  void reloadTimeline() => container.read(healthRecordsProvider.notifier).load();

  while (true) {
    if (!context.mounted) return;
    final pick = await showAppModal<_Handoff>(
      context,
      maxWidth: 448,
      title: 'Add to My Health',
      builder: (_) => _PickStep(session: session),
    );
    if (pick == null || !context.mounted) return;

    if (pick == _Handoff.lab) {
      final res = await showLabUploadModal(context);
      switch (res.outcome) {
        case LabFlowOutcome.saved:
          reloadTimeline();
          router.push('/lab-reports/${res.reportId}');
          return;
        case LabFlowOutcome.closed:
          reloadTimeline();
          return;
        case LabFlowOutcome.chooseAnother:
          // A failed read sends the patient back to the very first step.
          session.reset();
          continue;
        case LabFlowOutcome.cancel:
          // Cancelling mid-transfer returns to the document-type step, not the
          // file picker — the file is still around from the confirm step.
          session.choosing = true;
          continue;
      }
    } else {
      final res = await showPrescriptionUploadModal(context);
      switch (res) {
        case RxFlowOutcome.closed:
          reloadTimeline();
          return;
        case RxFlowOutcome.chooseAnother:
          session.reset();
          continue;
        case RxFlowOutcome.cancel:
          session.choosing = true;
          continue;
      }
    }
  }
}

enum _Handoff { lab, rx }

enum _Choice { labReport, prescription, scan, discharge, consultation, other }

class _ChoiceSpec {
  final _Choice key;
  final String label;
  final String hint;
  final IconData icon;
  final bool comingSoon;
  final bool imaging;
  const _ChoiceSpec(this.key, this.label, this.hint, this.icon,
      {this.comingSoon = false, this.imaging = false});
}

// Only lab reports and prescriptions run through extraction today. The rest stay
// visible (so the roadmap is legible) but blurred and unclickable until their
// own read/handle path is ready.
const _choices = <_ChoiceSpec>[
  _ChoiceSpec(_Choice.labReport, 'Lab report', 'To track your health metrics', PhosphorIconsFill.flask),
  _ChoiceSpec(_Choice.prescription, 'Prescription', 'To track your treatments',
      PhosphorIconsFill.prescription),
  _ChoiceSpec(_Choice.scan, 'Scan or imaging', 'X-ray, MRI, CT, ultrasound', PhosphorIconsFill.image,
      comingSoon: true, imaging: true),
  _ChoiceSpec(_Choice.discharge, 'Discharge summary', 'From a hospital stay',
      PhosphorIconsFill.hospital,
      comingSoon: true),
  _ChoiceSpec(_Choice.consultation, 'Consultation note', "A doctor's visit notes",
      PhosphorIconsFill.stethoscope,
      comingSoon: true),
  _ChoiceSpec(_Choice.other, 'Something else', 'Stored in your records', PhosphorIconsFill.file,
      comingSoon: true),
];

_Choice? _fromGuess(DocumentKind? k) {
  switch (k) {
    case DocumentKind.labReport:
      return _Choice.labReport;
    case DocumentKind.prescription:
      return _Choice.prescription;
    case DocumentKind.other:
      return _Choice.other;
    case null:
      return null;
  }
}

_ChoiceSpec _specOf(_Choice c) => _choices.firstWhere((s) => s.key == c);

class _Session {
  String? path;
  String? name;
  int? size;
  _Choice? guess;
  bool choosing = false;

  void reset() {
    path = null;
    name = null;
    size = null;
    guess = null;
    choosing = false;
  }
}

class _PickStep extends ConsumerStatefulWidget {
  final _Session session;
  const _PickStep({required this.session});

  @override
  ConsumerState<_PickStep> createState() => _PickStepState();
}

class _PickStepState extends ConsumerState<_PickStep> {
  _Session get s => widget.session;

  bool get _isDicom => s.name != null && s.name!.toLowerCase().endsWith('.dcm');

  void _pick(String path, String name, int size) {
    setState(() {
      s.path = path;
      s.name = name;
      s.size = size;
      // Imaging files can only be imaging; everything else gets a filename guess.
      final guessed = name.toLowerCase().endsWith('.dcm')
          ? _Choice.scan
          : _fromGuess(guessDocumentKind(name));
      s.guess = guessed;
      // A guessed type that isn't ready yet skips straight to the full chooser
      // rather than offering a confirm step for something unclickable.
      final guessedComingSoon = guessed != null && _specOf(guessed).comingSoon;
      s.choosing = guessed == null || guessedComingSoon;
    });
  }

  Future<void> _takePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null || !mounted) return;
      final stamp =
          DateTime.now().toIso8601String().substring(0, 19).replaceAll(RegExp(r'[:T]'), '-');
      _pick(file.path, 'scan-$stamp.jpg', await file.length());
    } catch (_) {
      // Camera unavailable / permission denied — the upload path still works.
    }
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'dcm'],
    );
    final f = res?.files.single;
    if (f == null || f.path == null || !mounted) return;
    _pick(f.path!, f.name, f.size > 0 ? f.size : await File(f.path!).length());
  }

  void _confirm(_Choice choice) {
    final path = s.path, name = s.name;
    if (path == null || name == null) return;
    if (choice == _Choice.labReport) {
      ref.read(labReportsProvider.notifier).startUpload(path, name);
      Navigator.of(context).pop(_Handoff.lab);
    } else if (choice == _Choice.prescription) {
      ref.read(prescriptionsProvider.notifier).startUpload(path, name);
      Navigator.of(context).pop(_Handoff.rx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final options = _isDicom ? _choices.where((c) => c.imaging).toList() : _choices;

    if (s.path == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40, bottom: 20),
            child: Text(
              "Add anything from your healthcare — a lab report, prescription, scan or discharge summary. You'll check what we read before it joins your record.",
              style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
            ),
          ),
          _EntryButton(
            icon: PhosphorIconsFill.camera,
            title: 'Scan / Take photo',
            hint: 'Use your camera',
            onTap: _takePhoto,
          ),
          const SizedBox(height: 12),
          _EntryButton(
            icon: PhosphorIconsFill.uploadSimple,
            title: 'Upload document',
            hint: 'PDF or image from your device',
            onTap: _upload,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsFill.fileText, size: 20.8, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.08,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      Formatters.fileSize(s.size ?? 0),
                      style: TextStyle(fontSize: 12.16, height: 1.5, color: t.ink3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(s.reset),
                child: const Text(
                  'Change file',
                  style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: AppColors.teal),
                ),
              ),
            ],
          ),
        ),
        if (s.guess != null && !s.choosing)
          Column(
            children: [
              Text(
                'We think this is a ${_specOf(s.guess!).label.toLowerCase()}. Is that correct?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WebButton(
                    label: 'Yes',
                    onTap: () => _confirm(s.guess!),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  const SizedBox(width: 10),
                  WebButton(
                    label: 'Change',
                    variant: WebButtonVariant.ghost,
                    onTap: () => setState(() => s.choosing = true),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                ],
              ),
            ],
          )
        else ...[
          Text(
            'What kind of document is this?',
            style: TextStyle(fontSize: 14.72, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 12),
          for (final c in options) ...[
            c.comingSoon
                ? _ComingSoonTile(spec: c)
                : _ChoiceTile(
                    spec: c,
                    highlighted: c.key == s.guess,
                    onTap: () => _confirm(c.key),
                  ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _EntryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;
  const _EntryButton({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22.4, color: AppColors.teal),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
              ),
              Text(hint, style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final _ChoiceSpec spec;
  final bool highlighted;
  final VoidCallback onTap;
  const _ChoiceTile({required this.spec, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted ? AppColors.teal.withValues(alpha: 0.45) : t.line,
            ),
          ),
          child: _ChoiceContent(spec: spec),
        ),
      ),
    );
  }
}

class _ChoiceContent extends StatelessWidget {
  final _ChoiceSpec spec;
  const _ChoiceContent({required this.spec});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(spec.icon, size: 18.4, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.label,
                style: TextStyle(
                  fontSize: 13.76,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: t.ink,
                ),
              ),
              Text(
                spec.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.84, height: 1.5, color: t.ink3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final _ChoiceSpec spec;
  const _ComingSoonTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Stack(
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: _ChoiceContent(spec: spec),
            ),
            Positioned.fill(
              child: Container(
                color: t.card.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Coming soon',
                    style: TextStyle(
                      fontSize: 11.2,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: t.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
