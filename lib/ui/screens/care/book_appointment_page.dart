import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appointment.dart';
import '../../../state/appointments_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

const _appointmentTypes = [
  'General Consultation',
  'Follow-up',
  'Report Review',
  'Medication Review',
  'Preventive Health Check',
  'Urgent Consultation',
];

// `--color-accent` — the coral-orange the booking stepper highlights with.
const _accent = Color(0xFFF27649);

enum _Step { provider, slot, review }

/// Direct booking: find a doctor, pick a time, confirm. Ported from
/// `BookAppointmentPage.tsx`.
///
/// Reachable from the dashboard without ever opening a chat. AI is not on this
/// path — when the patient *does* arrive from a conversation the only difference
/// is a `conversationId` in the query string, which is carried through and later
/// offered as one more shareable context item.
class BookAppointmentPage extends ConsumerStatefulWidget {
  /// Query parameters: `conversation`, `doctor`, `followUp`, `journey`, `concern`.
  final Map<String, String> params;
  const BookAppointmentPage({super.key, this.params = const {}});

  @override
  ConsumerState<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  _Step _step = _Step.provider;
  List<Clinician>? _providers;
  Clinician? _provider;
  List<SlotDay>? _days;
  Slot? _slot;
  String _type = _appointmentTypes.first;
  late final TextEditingController _reason =
      TextEditingController(text: widget.params['concern'] ?? '');
  bool _busy = false;

  String? get _conversationId => widget.params['conversation'];
  String? get _preselectedDoctorId => widget.params['doctor'];
  String? get _followUpRequestId => widget.params['followUp'];
  String? get _careJourneyId => widget.params['journey'];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final list = await ref.read(appointmentsServiceProvider).listProviders();
      if (!mounted) return;
      setState(() => _providers = list);

      // Arriving with ?doctor=<id> means the choice is already made, so skip the
      // picker rather than asking the patient to find the same doctor again. An id
      // that no longer resolves falls through to the full list instead of erroring
      // — the doctor may simply have been removed.
      final id = _preselectedDoctorId;
      final chosen = id == null ? null : list.where((p) => p.id == id).firstOrNull;
      if (chosen != null) _chooseProvider(chosen);
    } catch (_) {
      if (mounted) setState(() => _providers = const []);
    }
  }

  Future<void> _chooseProvider(Clinician p) async {
    setState(() {
      _provider = p;
      _slot = null;
      _days = null;
      _step = _Step.slot;
    });
    try {
      final days = await ref.read(appointmentsServiceProvider).listSlots(p.id);
      if (mounted) setState(() => _days = days);
    } catch (_) {
      if (mounted) setState(() => _days = const []);
    }
  }

  Future<void> _confirm() async {
    final provider = _provider, slot = _slot;
    if (provider == null || slot == null) return;
    setState(() => _busy = true);
    try {
      final reason = _reason.text.trim();
      final appointment = await ref.read(appointmentsServiceProvider).book(
            doctorId: provider.id,
            scheduledAt: slot.startsAt,
            appointmentType: _type,
            reason: reason.isEmpty ? null : reason,
            specialitySlug: provider.specialitySlug,
            // The label, and the only thing AI changes about this request.
            entrySource: _conversationId != null ? 'AI_GUIDED' : 'DIRECT_BOOKING',
            conversationId: _conversationId,
            followUpRequestId: _followUpRequestId,
            careJourneyId: _careJourneyId,
          );
      AppMessenger.success('Appointment requested');
      if (mounted) context.push('/care/${appointment.id}');
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      // The API client has already surfaced the message; stay on the step so the
      // patient can pick a different time.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ShellPage(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              BackSquareButton(
                semanticLabel: 'Back to My Care',
                onTap: () => context.canPop() ? context.pop() : context.go('/care'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book an appointment',
                      style: TextStyle(
                        fontSize: 27.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.816,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _conversationId != null
                            ? 'Continuing from your conversation. You choose what to share later.'
                            : 'Choose a doctor and a time that suits you.',
                        style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stepper
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _Step.values.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _step == _Step.values[i] ? _accent : t.card,
                        shape: BoxShape.circle,
                        border: _step == _Step.values[i] ? null : Border.all(color: t.line),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11.52,
                          fontWeight: FontWeight.w600,
                          color: _step == _Step.values[i] ? Colors.white : t.ink2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      const ['Doctor', 'Time', 'Review'][i],
                      style: TextStyle(
                        fontSize: 12.8,
                        height: 1.5,
                        color: _step == _Step.values[i] ? t.ink : t.ink2,
                      ),
                    ),
                    if (i < 2) ...[
                      const SizedBox(width: 8),
                      Text('›', style: TextStyle(fontSize: 12.8, color: t.line)),
                    ],
                  ],
                ),
            ],
          ),
        ),

        if (_step == _Step.provider) _buildProviders(context),
        if (_step == _Step.slot && _provider != null) _buildSlots(context),
        if (_step == _Step.review && _provider != null && _slot != null) _buildReview(context),
      ],
    );
  }

  Widget _buildProviders(BuildContext context) {
    final t = context.tokens;
    final providers = _providers;
    if (providers == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: AppSpinner(size: 40)),
      );
    }
    if (providers.isEmpty) {
      return LegacyCard(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No doctors are taking appointments right now.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5, color: t.ink2),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          LegacyCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providers[i].fullName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  providers[i].specialityName ?? 'General Medicine',
                  style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                ),
                if (providers[i].qualifications.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    providers[i].qualifications.join(', '),
                    style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink2),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LegacyButton(
                    label: 'View availability',
                    size: LegacyButtonSize.sm,
                    onPressed: () => _chooseProvider(providers[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlots(BuildContext context) {
    final t = context.tokens;
    final provider = _provider!;
    final days = _days;
    final available = (days ?? const <SlotDay>[]).where((d) => d.slots.isNotEmpty).toList();

    return LegacyCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.fullName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                  ),
                  if (provider.specialityName != null)
                    Text(
                      provider.specialityName!,
                      style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                    ),
                ],
              ),
              LegacyButton(
                label: 'Change doctor',
                variant: LegacyButtonVariant.secondary,
                size: LegacyButtonSize.sm,
                onPressed: () => setState(() => _step = _Step.provider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (days == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: AppSpinner(size: 24)),
            )
          else if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No free times in the next two weeks. Try another doctor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: t.ink2),
                ),
              ),
            )
          else
            for (final day in available) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  () {
                    final d = DateTime.tryParse('${day.date}T00:00:00');
                    return d == null ? day.date : Formatters.dayShort(d);
                  }(),
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink2,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in day.slots)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _slot = s;
                        _step = _Step.review;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.line),
                        ),
                        child: Text(
                          () {
                            final d = Formatters.tryParse(s.startsAt);
                            return d == null ? s.startsAt : Formatters.timeHm(d);
                          }(),
                          style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final t = context.tokens;
    final provider = _provider!;
    final slot = _slot!;
    final when = Formatters.tryParse(slot.startsAt);

    Widget label(String text) => Text(
          text,
          style: TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: t.ink2,
          ),
        );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: LegacyCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('DOCTOR'),
              Text(
                provider.fullName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
              ),
              if (provider.specialityName != null)
                Text(
                  provider.specialityName!,
                  style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                ),
              const SizedBox(height: 16),
              label('WHEN'),
              Text(
                when != null ? Formatters.appointmentLong(when) : slot.startsAt,
                style: TextStyle(fontSize: 16, height: 1.5, color: t.ink),
              ),
              const SizedBox(height: 16),
              label('TYPE'),
              const SizedBox(height: 4),
              WebSelect<String>(
                value: _type,
                height: 38,
                radius: 10,
                borderWidth: 1,
                fontSize: 14.4,
                options: [for (final x in _appointmentTypes) (value: x, label: x)],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              label('WHAT ARE YOU COMING IN FOR?'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.line),
                ),
                child: TextField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 3,
                  style: TextStyle(fontSize: 14.4, height: 1.5, color: t.ink),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'A sentence is enough.',
                    hintStyle: TextStyle(color: t.ink3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Sharing is decided AFTER confirmation, on the appointment itself, so
              // the patient sees the real list rather than a promise.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  // `bg-bg` → `--color-bg`
                  color: context.isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.line),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(PhosphorIconsRegular.lockSimple, size: 14, color: t.ink2),
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Once this is confirmed you will be shown exactly what may be shared with the doctor, and you choose each item.',
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink2),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LegacyButton(
                    label: _busy ? 'Requesting…' : 'Confirm appointment',
                    onPressed: _busy ? null : _confirm,
                  ),
                  LegacyButton(
                    label: 'Change time',
                    variant: LegacyButtonVariant.secondary,
                    onPressed: _busy ? null : () => setState(() => _step = _Step.slot),
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
