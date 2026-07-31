import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/soap.dart';
import '../../../../data/models/user.dart';
import '../../../../state/auth_provider.dart';
import '../../../../state/chat_provider.dart';
import 'nova_blocks.dart' show NovaRichText;

const Map<String, String> _sexLabels = {
  'male': 'Male',
  'female': 'Female',
  'intersex': 'Intersex',
  'prefer_not_to_say': 'Prefer not to say',
};

String _numStr(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Patient demographics from the canonical user record — missing fields
/// render as an em dash so a clinician sees what the record does/doesn't hold.
SoapPatientInfo _buildPatientInfo(User? user) {
  final name = [
    user?.firstName,
    user?.lastName,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
  final age = Formatters.ageFromDob(user?.dateOfBirth);
  final bmi = computeBmi(heightCm: user?.heightCm, weightKg: user?.weightKg);
  final sexLabel = user?.sex != null ? _sexLabels[user!.sex] : null;
  return SoapPatientInfo(
    name: name.isNotEmpty ? name : 'Unknown patient',
    age: age != null ? '$age yrs' : '—',
    sex: sexLabel ?? '—',
    height: user?.heightCm != null ? '${_numStr(user!.heightCm!)} cm' : '—',
    weight: user?.weightKg != null ? '${_numStr(user!.weightKg!)} kg' : '—',
    bmi: bmi != null ? '${bmi.value} (${bmi.category})' : null,
  );
}

String _fmtGenerated(String? iso) {
  final d = Formatters.tryParse(iso);
  if (d == null) return '';
  return '${Formatters.dateMedium(d)} · ${Formatters.messageTime(d)}';
}

String _fmtExpiry(String iso) {
  final d = Formatters.tryParse(iso);
  if (d == null) return '';
  return Formatters.dateMedium(d);
}

/// Prefilled WhatsApp share. No phone number → WhatsApp opens and lets the
/// user pick ANY recipient (chat or contact) to send the link to.
Uri _whatsappUri(String url) {
  final text =
      "Here's my consultation summary from Enervara for you to review:\n$url";
  return Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
}

/// Doctor-facing SOAP clinical handoff. NOT a chat message — a dedicated,
/// full-takeover overlay of the chat column. Ported from `SoapNotePanel.tsx`
/// (+ `SoapDocument.tsx` for the document body).
class SoapNotePanel extends ConsumerStatefulWidget {
  const SoapNotePanel({super.key});

  @override
  ConsumerState<SoapNotePanel> createState() => _SoapNotePanelState();
}

enum _ShareStatus { idle, creating, ready, error }

class _SoapNotePanelState extends ConsumerState<SoapNotePanel> {
  _ShareStatus _shareStatus = _ShareStatus.idle;
  String _shareToken = '';
  String _shareUrl = '';
  String _shareExpiresAt = '';

  Future<String?> _createShare(SoapNote note, String conversationId) async {
    setState(() => _shareStatus = _ShareStatus.creating);
    try {
      final link = await ref
          .read(soapServiceProvider)
          .createShare(conversationId, note);
      if (!mounted) return null;
      setState(() {
        _shareToken = link.token;
        _shareUrl = link.url;
        _shareExpiresAt = link.expiresAt;
        _shareStatus = _ShareStatus.ready;
      });
      return link.url;
    } catch (_) {
      // api interceptor already toasts the server message
      if (mounted) setState(() => _shareStatus = _ShareStatus.error);
      return null;
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppMessenger.success('Link copied — send it to your doctor');
  }

  Future<void> _ensureAndCopy(SoapNote note, String conversationId) async {
    if (_shareStatus == _ShareStatus.ready && _shareUrl.isNotEmpty) {
      await _copy(_shareUrl);
      return;
    }
    final u = await _createShare(note, conversationId);
    if (u != null) await _copy(u);
  }

  Future<void> _shareWhatsApp(SoapNote note, String conversationId) async {
    var url = _shareUrl;
    if (!(_shareStatus == _ShareStatus.ready && url.isNotEmpty)) {
      final u = await _createShare(note, conversationId);
      if (u == null) return;
      url = u;
    }
    final ok = await launchUrl(
      _whatsappUri(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) AppMessenger.error('Could not open WhatsApp');
  }

  Future<void> _revoke() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke this link?'),
        content: const Text(
          'Anyone you already sent it to will no longer be able to open it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Revoke',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(soapServiceProvider).revokeShare(_shareToken);
      if (!mounted) return;
      setState(() {
        _shareStatus = _ShareStatus.idle;
        _shareToken = '';
        _shareUrl = '';
      });
      AppMessenger.success('Link revoked');
    } catch (_) {
      /* interceptor toasts */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    final soap = chat.soap;
    final note = soap.note;
    final user = ref.watch(authProvider.select((s) => s.user));
    final patient = _buildPatientInfo(user);
    final generated = _fmtGenerated(note?.generatedAt);
    final conversationId = chat.activeConversationId;
    final controller = ref.read(chatProvider.notifier);

    return Positioned.fill(
      child: Container(
        color: t.card,
        child: SafeArea(
          child: Column(
            children: [
              // Action header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  children: [
                    _headerButton(
                      context,
                      icon: PhosphorIconsRegular.arrowLeft,
                      label: 'Back',
                      onTap: controller.closeSoap,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Consultation summary',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          Text(
                            'SOAP clinical handoff${generated.isNotEmpty ? ' · $generated' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.8, color: t.ink3),
                          ),
                        ],
                      ),
                    ),
                    if (soap.status == SoapStatus.ready &&
                        note != null &&
                        conversationId != null) ...[
                      _headerButton(
                        context,
                        icon: PhosphorIconsRegular.arrowClockwise,
                        label: 'Regenerate',
                        onTap: controller.generateSoap,
                      ),
                      const SizedBox(width: 6),
                      _headerButton(
                        context,
                        icon: PhosphorIconsFill.whatsappLogo,
                        label: 'Share',
                        accent: true,
                        onTap: () => _shareWhatsApp(note, conversationId),
                      ),
                    ],
                  ],
                ),
              ),

              // Loading
              if (soap.status == SoapStatus.loading)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.teal,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Preparing an updated summary for your doctor…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.4,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Regenerated from the full conversation so far — this can take a moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: t.ink3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Error
              if (soap.status == SoapStatus.error)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsFill.warning,
                              size: 20,
                              color: AppColors.coral,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            soap.error ??
                                'Could not prepare the summary. Please try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: controller.generateSoap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Text(
                                'Try again',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Ready — clinical document + share card
              if (soap.status == SoapStatus.ready && note != null)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PatientCard(patient: patient),
                        const SizedBox(height: 12),
                        _SoapSections(note: note),
                        if (note.unavailable.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _UnavailableCard(items: note.unavailable),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'AI-generated from a patient chat — for discussion with a licensed clinician, not a diagnosis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.6,
                            height: 1.35,
                            color: t.ink3,
                          ),
                        ),
                        if (conversationId != null) ...[
                          const SizedBox(height: 14),
                          _ShareCard(
                            status: _shareStatus,
                            url: _shareUrl,
                            expiresAt: _shareExpiresAt,
                            onWhatsApp: () =>
                                _shareWhatsApp(note, conversationId),
                            onCopy: () => _ensureAndCopy(note, conversationId),
                            onOpen: _shareUrl.isEmpty
                                ? null
                                : () => launchUrl(
                                    Uri.parse(_shareUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                            onRevoke: _revoke,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent ? AppColors.teal : t.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: accent ? Colors.white : t.ink2),
      ),
    );
  }
}

// ─── Patient demographics card ───────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final SoapPatientInfo patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final metas = <(String, String)>[
      ('Age', patient.age),
      ('Sex', patient.sex),
      ('Height', patient.height),
      ('Weight', patient.weight),
      if (patient.bmi != null) ('BMI', patient.bmi!),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.user,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      'PATIENT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: t.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final m in metas)
                SizedBox(
                  width: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.$1.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: t.ink3,
                        ),
                      ),
                      Text(
                        m.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.6,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── S/O/A/P sections ────────────────────────────────────────────────────────

class _SoapSectionSpec {
  final String key;
  final String label;
  final String letter;
  final String hint;
  const _SoapSectionSpec(this.key, this.label, this.letter, this.hint);
}

const List<_SoapSectionSpec> _kSoapSections = [
  _SoapSectionSpec(
    'subjective',
    'Subjective',
    'S',
    'Why the patient is here — reported symptoms, duration, history',
  ),
  _SoapSectionSpec(
    'objective',
    'Objective',
    'O',
    'Observations, measurements & examination findings reported',
  ),
  _SoapSectionSpec(
    'assessment',
    'Assessment',
    'A',
    'Current clinical impression & any uncertainty',
  ),
  _SoapSectionSpec('plan', 'Plan', 'P', 'Recommended next actions'),
];

class _SoapSections extends StatelessWidget {
  final SoapNote note;
  const _SoapSections({required this.note});

  String _valueFor(String key) {
    switch (key) {
      case 'subjective':
        return note.subjective;
      case 'objective':
        return note.objective;
      case 'assessment':
        return note.assessment;
      default:
        return note.plan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in _kSoapSections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _section(context, s, _valueFor(s.key), t),
          ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    _SoapSectionSpec s,
    String value,
    dynamic t,
  ) {
    final emphasise = s.key == 'assessment';
    final body = Padding(
      padding: EdgeInsets.only(left: emphasise ? 0 : 34),
      child: value.trim().isNotEmpty
          ? NovaRichText(
              text: value,
              style: TextStyle(fontSize: 13.4, height: 1.4, color: t.ink),
            )
          : Text(
              'Not documented',
              style: TextStyle(
                fontSize: 12.8,
                fontStyle: FontStyle.italic,
                color: t.ink3,
              ),
            ),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            s.letter,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.label,
                style: TextStyle(
                  fontSize: emphasise ? 14.5 : 13.6,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              Text(
                s.hint,
                style: TextStyle(fontSize: 10.4, height: 1.3, color: t.ink3),
              ),
            ],
          ),
        ),
      ],
    );

    if (emphasise) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [header, const SizedBox(height: 6), body],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [header, const SizedBox(height: 5), body],
      ),
    );
  }
}

// ─── Not documented ──────────────────────────────────────────────────────────

class _UnavailableCard extends StatelessWidget {
  final List<String> items;
  const _UnavailableCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.ink3,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsBold.minus,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NOT DOCUMENTED IN THIS CONVERSATION',
                style: TextStyle(
                  fontSize: 10.6,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: t.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final u in items)
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.ink2,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      u,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: t.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Share with your doctor ──────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final _ShareStatus status;
  final String url;
  final String expiresAt;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final VoidCallback onRevoke;

  const _ShareCard({
    required this.status,
    required this.url,
    required this.expiresAt,
    required this.onWhatsApp,
    required this.onCopy,
    required this.onOpen,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final creating = status == _ShareStatus.creating;
    final ready = status == _ShareStatus.ready;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.shareNetwork,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Share with your doctor',
                      style: TextStyle(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      'Send a private link on WhatsApp your doctor can open to read this summary — no account needed.',
                      style: TextStyle(
                        fontSize: 11.3,
                        height: 1.3,
                        color: t.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!ready)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: creating ? null : onWhatsApp,
                  child: Opacity(
                    opacity: creating ? 0.6 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (creating)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              PhosphorIconsFill.whatsappLogo,
                              size: 16,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            creating
                                ? 'Preparing…'
                                : status == _ShareStatus.error
                                ? 'Try again'
                                : 'Send on WhatsApp',
                            style: const TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: creating ? null : onCopy,
                  child: Opacity(
                    opacity: creating ? 0.6 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: t.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.link,
                            size: 15,
                            color: t.ink2,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Copy link',
                            style: TextStyle(
                              fontSize: 12.6,
                              fontWeight: FontWeight.w600,
                              color: t.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.ink),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.copy,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onOpen,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: t.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.arrowSquareOut,
                        size: 14,
                        color: t.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onWhatsApp,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsFill.whatsappLogo,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Send on WhatsApp',
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: 12,
                  color: t.ink3,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Anyone with this link can view this summary'
                    '${expiresAt.isNotEmpty ? ' · expires ${_fmtExpiry(expiresAt)}' : ''}',
                    style: TextStyle(
                      fontSize: 10.4,
                      height: 1.3,
                      color: t.ink3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onRevoke,
              child: Text(
                'Revoke link',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.coral,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
