import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/models/appointment.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/lab_report.dart';
import '../../../data/models/prescription.dart';
import '../../../state/appointments_provider.dart';
import '../../../state/chat_provider.dart';
import '../../../state/lab_reports_provider.dart';
import '../../../state/nova_ui_provider.dart';
import '../../../state/prescriptions_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/speciality_icon.dart';
import '../dashboard/widgets/speciality_pickers.dart';
import '../health_records/add_to_my_health_flow.dart';
import 'consultation_mode_badge.dart';

const _followUpLabels = <String, String>{
  'APPOINTMENT': 'Follow-up appointment',
  'INVESTIGATION': 'Investigation',
  'MONITORING': 'Monitoring',
  'REVIEW': 'Review',
};

String _when(String iso) {
  final d = Formatters.tryParse(iso);
  return d == null ? '' : Formatters.appointmentShort(d);
}

Color _statusTone(BuildContext context, String status) {
  final t = context.tokens;
  if (status == 'CANCELLED' || status == 'NO_SHOW') return t.ink3;
  if (status == 'COMPLETED') return context.isDark ? AppColors.teal : AppColors.tealD;
  if (status == 'FOLLOW_UP_DUE') return AppColors.amber;
  return t.ink2;
}

class _CareData {
  final AppointmentsList appointments;
  final List<FollowUp> followUps;
  final List<ChatConversation> conversations;
  final List<LabReportListItem> labToReview;
  final List<PrescriptionListItem> rxToReview;
  const _CareData(
    this.appointments,
    this.followUps,
    this.conversations,
    this.labToReview,
    this.rxToReview,
  );
}

class _NextAction {
  final String id;
  final IconData icon;
  final String text;
  final String? to;
  final VoidCallback? onTap;
  final String? cta;
  const _NextAction({
    required this.id,
    required this.icon,
    required this.text,
    this.to,
    this.onTap,
    this.cta,
  });
}

/// My Care — the patient's active care journey: "What care am I receiving, what
/// happened in my consultations, and what do I need to do next?" Ported from
/// `MyCarePage.tsx`.
///
/// Consultations, follow-ups and appointments belong here. Reports and
/// prescriptions are health-record events and live in Health Records; they appear
/// here only as an action to take ("review what we read"). Every appointment entry
/// point converges on this page: booked directly, from an AI conversation, by a
/// clinic, or at a walk-in desk.
class MyCarePage extends ConsumerStatefulWidget {
  const MyCarePage({super.key});

  @override
  ConsumerState<MyCarePage> createState() => _MyCarePageState();
}

class _MyCarePageState extends ConsumerState<MyCarePage> {
  _CareData? _data;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    final appts = ref
        .read(appointmentsServiceProvider)
        .listMine()
        .catchError((_) => const AppointmentsList());
    final follow = ref
        .read(appointmentsServiceProvider)
        .listFollowUps()
        .catchError((_) => <FollowUp>[]);
    final convos = ref
        .read(chatServiceProvider)
        .listAll(limit: 50)
        .catchError((_) => <ChatConversation>[]);
    final labs = ref
        .read(labReportsServiceProvider)
        .listReports(status: 'READY_FOR_REVIEW')
        .catchError((_) => <LabReportListItem>[]);
    final rxs = ref
        .read(prescriptionsServiceProvider)
        .listPrescriptions(status: 'READY_FOR_REVIEW')
        .catchError((_) => <PrescriptionListItem>[]);
    final data = _CareData(
      await appts,
      (await follow).where((f) => f.status == 'OPEN').toList(),
      await convos,
      await labs,
      await rxs,
    );
    if (!_disposed) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = _data;

    // The latest conversation per speciality, most recent first, active care only
    // — a conversation the backend has marked resolved is previous care and has no
    // place on this page. The first is the ongoing care journey; the rest are
    // recent care.
    List<ChatConversation> journeys = const [];
    if (data != null) {
      final active = data.conversations.where((c) => c.isActiveCare).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      final latest = <String, ChatConversation>{};
      for (final c in active) {
        latest.putIfAbsent(c.specialitySlug, () => c);
      }
      journeys = latest.values.toList();
    }
    final ongoing = journeys.isNotEmpty ? journeys.first : null;
    final recent = journeys.skip(1).take(4).toList();
    final ongoingFollowUp = (ongoing != null && data != null)
        ? data.appointments.upcoming
            .where((a) =>
                a.specialitySlug == ongoing.specialitySlug ||
                a.provider.specialitySlug == ongoing.specialitySlug)
            .firstOrNull
        : null;

    final nextActions = <_NextAction>[
      if (data != null) ...[
        for (final f in data.followUps)
          () {
            final due = f.dueOn != null
                ? ' · due ${Formatters.eventDate('${f.dueOn}T00:00:00')}'
                : '';
            final note = f.note ?? '';
            if (f.kind == 'INVESTIGATION') {
              return _NextAction(
                id: f.id,
                icon: PhosphorIconsRegular.uploadSimple,
                text: 'Upload requested report${note.isNotEmpty ? ' — $note' : ''}$due',
                onTap: () => showAddToMyHealthFlow(context),
                cta: 'Add',
              );
            }
            if (f.kind == 'APPOINTMENT' || f.kind == 'REVIEW') {
              return _NextAction(
                id: f.id,
                icon: PhosphorIconsRegular.calendarPlus,
                text:
                    'Complete follow-up — ${_followUpLabels[f.kind]}${note.isNotEmpty ? ': $note' : ''}$due',
                to: '/care/book?followUp=${f.id}&journey=${f.careJourneyId}',
                cta: 'Book it',
              );
            }
            return _NextAction(
              id: f.id,
              icon: PhosphorIconsRegular.heartbeat,
              text: '${_followUpLabels[f.kind] ?? f.kind}${note.isNotEmpty ? ' — $note' : ''}$due',
            );
          }(),
        for (final r in data.labToReview)
          _NextAction(
            id: 'lab-${r.id}',
            icon: PhosphorIconsRegular.flask,
            text: 'Review the values we read from your ${labReportTypeLabel(r.reportType)}',
            to: '/lab-reports/${r.id}',
            cta: 'Review',
          ),
        for (final p in data.rxToReview)
          _NextAction(
            id: 'rx-${p.id}',
            icon: PhosphorIconsRegular.prescription,
            text: 'Review the medicines we read from your prescription',
            to: '/prescriptions/${p.id}',
            cta: 'Review',
          ),
      ],
    ];

    final ongoingSpec = ongoing != null ? specialityBySlug(ongoing.specialitySlug) : null;

    return ShellPage(
      children: [
        PageHeader(
          title: 'My Care',
          subtitle: "The care you're receiving, and what to do next.",
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/care/book'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.calendarPlus, size: 16, color: t.ink),
                      const SizedBox(width: 8),
                      Text(
                        'Book an appointment',
                        style: TextStyle(
                          fontSize: 14.08,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              WebButton(
                label: 'Start new care',
                icon: PhosphorIconsBold.plus,
                fontSize: 14.08,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onTap: () => showSpecialityPickerModal(context, ref),
              ),
            ],
          ),
        ),
        if (data == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: AppSpinner(size: 40)),
          )
        else ...[
          // ── Ongoing + recent care ──
          const SectionLabel('Ongoing care'),
          if (ongoing != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: -18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ongoingSpec != null ? AppColors.hex(ongoingSpec.color) : AppColors.teal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SpecialityIcon(
                          icon: ongoingSpec?.icon ?? 'Stethoscope',
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ongoingSpec?.name ?? ongoing.specialitySlug,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.8,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConsultationModeBadge(mode: ongoing.mode),
                              ],
                            ),
                            Text(
                              ongoing.title.isNotEmpty ? ongoing.title : 'Consultation with Nova',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'Last consultation',
                          value: Formatters.eventDate(ongoing.lastMessageAt),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          label: 'Follow-up',
                          value: ongoingFollowUp != null
                              ? Formatters.eventDate(ongoingFollowUp.scheduledAt)
                              : 'None booked',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref
                        .read(novaUiProvider.notifier)
                        .openExistingConversation(ongoing.id, ongoing.specialitySlug),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 14.08,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: AppColors.teal,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(PhosphorIconsRegular.arrowRight, size: 12.8, color: AppColors.teal),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            DashedBox(
              radius: 18,
              width: double.infinity,
              color: t.card,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'No ongoing care',
                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start a consultation and it will be tracked here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                  ),
                ],
              ),
            ),

          if (recent.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionLabel('Recent care'),
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _RecentRow(
                conversation: recent[i],
                onTap: () => ref
                    .read(novaUiProvider.notifier)
                    .openExistingConversation(recent[i].id, recent[i].specialitySlug),
              ),
            ],
          ],

          // ── Next actions ──
          const SizedBox(height: 24),
          const SectionLabel('Next actions'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: nextActions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.checkCircle, size: 16, color: AppColors.teal),
                        const SizedBox(width: 8),
                        Text(
                          "You're all caught up.",
                          style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final a in nextActions)
                        _NextActionRow(
                          action: a,
                          onTap: a.to != null
                              ? () => context.push(a.to!)
                              : a.onTap,
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSpecialityPickerModal(context, ref),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.plus, size: 14, color: AppColors.teal),
                  SizedBox(width: 6),
                  Text(
                    'Start new care',
                    style: TextStyle(
                      fontSize: 14.08,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Appointments ──
          const SizedBox(height: 28),
          const SectionLabel('Upcoming appointments'),
          if (data.appointments.upcoming.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.line),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Nothing booked. '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => context.push('/care/book'),
                        child: const Text(
                          'Book an appointment',
                          style: TextStyle(
                            fontSize: 14.08,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < data.appointments.upcoming.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _AppointmentRow(appointment: data.appointments.upcoming[i]),
                ],
              ],
            ),
          if (data.appointments.past.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionLabel('Past appointments'),
            Column(
              children: [
                for (var i = 0; i < data.appointments.past.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _AppointmentRow(appointment: data.appointments.past[i]),
                ],
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.52, height: 1.5, color: t.ink3)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.44,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;
  const _RecentRow({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spec = specialityBySlug(conversation.specialitySlug);
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: spec != null ? AppColors.hex(spec.color) : AppColors.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SpecialityIcon(icon: spec?.icon ?? 'Stethoscope', size: 17, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spec?.name ?? conversation.specialitySlug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.4,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ConsultationModeBadge(mode: conversation.mode),
              const SizedBox(width: 12),
              Text(
                Formatters.eventDate(conversation.lastMessageAt),
                style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
              ),
              const SizedBox(width: 12),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextActionRow extends StatelessWidget {
  final _NextAction action;
  final VoidCallback? onTap;
  const _NextActionRow({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(action.icon, size: 16, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.text,
              style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink),
            ),
          ),
          if (action.cta != null) ...[
            const SizedBox(width: 12),
            Text(
              action.cta!,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: AppColors.teal,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: content);
  }
}

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;
  const _AppointmentRow({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = appointment;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/care/${a.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.appointmentType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      '${a.provider.displayName != null ? 'Dr ${a.provider.displayName}' : 'Provider to be assigned'}'
                      '${a.provider.specialityName != null ? ' · ${a.provider.specialityName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _when(a.scheduledAt),
                        style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink2),
                      ),
                    ),
                    if (a.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          a.reason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConsultationModeBadge(mode: a.mode),
                      const SizedBox(width: 8),
                      Text(
                        appointmentStatusLabel(a.status),
                        style: TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: _statusTone(context, a.status),
                        ),
                      ),
                    ],
                  ),
                  // Shown because a patient should recognise an appointment a
                  // clinic made for them.
                  if (a.entrySource == 'PROVIDER_CREATED')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Booked by the clinic',
                          style: TextStyle(fontSize: 11.52, height: 1.5, color: t.ink3)),
                    )
                  else if (a.entrySource == 'WALK_IN')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Walk-in',
                          style: TextStyle(fontSize: 11.52, height: 1.5, color: t.ink3)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
