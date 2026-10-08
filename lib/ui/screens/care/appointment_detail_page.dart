import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appointment.dart';
import '../../../state/appointments_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

/// One appointment, and the decision the patient owns about it. Ported from
/// `AppointmentDetailPage.tsx`.
///
/// This is where the context-sharing flow actually happens: confirmed → what may
/// be shared → the patient authorises → the provider can see it. Each row names a
/// record the patient already has a screen for; the content itself never travels
/// through here, which is why withdrawing a share genuinely removes access.
class AppointmentDetailPage extends ConsumerStatefulWidget {
  final String id;
  const AppointmentDetailPage({super.key, required this.id});

  @override
  ConsumerState<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends ConsumerState<AppointmentDetailPage> {
  Appointment? _appointment;
  List<ContextItem> _context = const [];
  List<StatusEvent> _history = const [];
  bool _loading = true;
  String? _busyItem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(appointmentsServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _appointment = data.appointment;
        _context = data.context;
        _history = data.history;
      });
    } catch (_) {
      /* surfaced by the API client; the not-found card renders */
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(ContextItem item, String decision) async {
    setState(() => _busyItem = item.id);
    try {
      final updated = await ref
          .read(appointmentsServiceProvider)
          .decideContext(widget.id, item.id, decision);
      if (mounted) {
        setState(() => _context = [for (final c in _context) c.id == updated.id ? updated : c]);
      }
    } finally {
      if (mounted) setState(() => _busyItem = null);
    }
  }

  Future<void> _decideAll(String decision) async {
    setState(() => _busyItem = 'all');
    try {
      final list = await ref.read(appointmentsServiceProvider).decideAllContext(widget.id, decision);
      if (mounted) setState(() => _context = list);
    } finally {
      if (mounted) setState(() => _busyItem = null);
    }
  }

  Future<void> _cancel() async {
    try {
      final updated = await ref.read(appointmentsServiceProvider).cancel(widget.id);
      if (mounted) setState(() => _appointment = updated);
      AppMessenger.success('Appointment cancelled');
    } catch (_) {
      /* surfaced by the API client */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = _appointment;

    if (_loading) {
      return const Center(child: AppSpinner(size: 40));
    }
    if (a == null) {
      return ShellPage(
        children: [
          LegacyCard(
            padding: const EdgeInsets.all(24),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'That appointment could not be found. '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => context.go('/care'),
                      child: const Text(
                        'Back to My Care',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFF27649),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFF27649),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5, color: t.ink2),
            ),
          ),
        ],
      );
    }

    final shared = _context.where((c) => c.shareStatus == 'AUTHORIZED').length;
    final undecided = _context.where((c) => c.shareStatus == 'PROPOSED').length;
    final when = Formatters.tryParse(a.scheduledAt);
    final busy = _busyItem != null;

    Widget h2(String text) => Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
        );

    return ShellPage(
      children: [
        // Header
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
                      a.appointmentType,
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
                        '${appointmentStatusLabel(a.status)} · ${when != null ? Formatters.appointmentLong(when) : a.scheduledAt}',
                        style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Context sharing ──
        LegacyCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32 - 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        h2('What the doctor may see'),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Nothing is shared until you choose it. You can withdraw at any time.',
                            style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_context.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LegacyButton(
                          label: 'Share all',
                          variant: LegacyButtonVariant.secondary,
                          size: LegacyButtonSize.sm,
                          onPressed: busy ? null : () => _decideAll('AUTHORIZED'),
                        ),
                        const SizedBox(width: 8),
                        LegacyButton(
                          label: 'Share none',
                          variant: LegacyButtonVariant.secondary,
                          size: LegacyButtonSize.sm,
                          onPressed: busy ? null : () => _decideAll('DECLINED'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_context.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      a.status == 'REQUESTED'
                          ? 'Your context will be prepared once the clinic confirms this appointment.'
                          : 'There is nothing on file to share for this visit yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$shared of ${_context.length} shared${undecided > 0 ? ' · $undecided still to decide' : ''}',
                    style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                  ),
                ),
                for (var i = 0; i < _context.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ContextRow(
                    item: _context[i],
                    busy: busy,
                    onDecide: (d) => _decide(_context[i], d),
                  ),
                ],
              ],
            ],
          ),
        ),

        // ── Lifecycle history ──
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 16),
          LegacyCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 12), child: h2('History')),
                for (var i = 0; i < _history.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _HistoryRow(event: _history[i]),
                ],
              ],
            ),
          ),
        ],

        // ── Summary and actions ──
        const SizedBox(height: 16),
        LegacyCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                label: 'DOCTOR',
                value: a.provider.displayName != null ? 'Dr ${a.provider.displayName}' : 'To be assigned',
                sub: a.provider.specialityName,
              ),
              if (a.reason != null) ...[
                const SizedBox(height: 12),
                _Field(label: 'REASON', value: a.reason!, valueSize: 14.4),
              ],
              if (a.cancellationReason != null) ...[
                const SizedBox(height: 12),
                _Field(label: 'NOTE', value: a.cancellationReason!, valueSize: 14.4),
              ],
            ],
          ),
        ),
        if (isAppointmentChangeable(a.status)) ...[
          const SizedBox(height: 16),
          LegacyCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LegacyButton(
                  label: 'Book a different time',
                  variant: LegacyButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => context.push('/care/book?journey=${a.careJourneyId ?? ''}'),
                ),
                const SizedBox(height: 8),
                LegacyButton(
                  label: 'Cancel appointment',
                  variant: LegacyButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _cancel,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double valueSize;
  const _Field({required this.label, required this.value, this.sub, this.valueSize = 16});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.5, color: t.ink2),
        ),
        Text(value, style: TextStyle(fontSize: valueSize, height: 1.5, color: t.ink)),
        if (sub != null)
          Text(sub!, style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2)),
      ],
    );
  }
}

class _ContextRow extends StatelessWidget {
  final ContextItem item;
  final bool busy;
  final ValueChanged<String> onDecide;
  const _ContextRow({required this.item, required this.busy, required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget buttons;
    if (item.shareStatus == 'AUTHORIZED') {
      buttons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Shared',
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 8),
          LegacyButton(
            label: 'Withdraw',
            variant: LegacyButtonVariant.secondary,
            size: LegacyButtonSize.sm,
            onPressed: busy ? null : () => onDecide('REVOKED'),
          ),
        ],
      );
    } else if (item.shareStatus == 'PROPOSED') {
      buttons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LegacyButton(
            label: 'Share',
            size: LegacyButtonSize.sm,
            onPressed: busy ? null : () => onDecide('AUTHORIZED'),
          ),
          const SizedBox(width: 8),
          LegacyButton(
            label: 'Not this',
            variant: LegacyButtonVariant.secondary,
            size: LegacyButtonSize.sm,
            onPressed: busy ? null : () => onDecide('DECLINED'),
          ),
        ],
      );
    } else {
      buttons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Not shared', style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2)),
          const SizedBox(width: 8),
          LegacyButton(
            label: 'Share',
            variant: LegacyButtonVariant.secondary,
            size: LegacyButtonSize.sm,
            onPressed: busy ? null : () => onDecide('AUTHORIZED'),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.line),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32 - 40 - 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kContextKindLabels[item.kind] ?? item.kind,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink2,
                  ),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.4, height: 1.5, color: t.ink),
                ),
              ],
            ),
          ),
          buttons,
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final StatusEvent event;
  const _HistoryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = Formatters.tryParse(event.occurredAt);
    final text =
        '${event.from != null ? '${appointmentStatusLabel(event.from!)} → ' : ''}${appointmentStatusLabel(event.to)}${event.reason != null ? ' — ${event.reason}' : ''}';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 12,
      runSpacing: 2,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32 - 40),
          child: Text(text, style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink)),
        ),
        Text(
          d != null ? Formatters.dayMonthTime(d) : '',
          style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
        ),
      ],
    );
  }
}
