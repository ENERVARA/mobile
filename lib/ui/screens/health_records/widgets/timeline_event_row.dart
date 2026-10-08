import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/accent.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/timeline.dart';
import '../../../../state/nova_ui_provider.dart';

/// Opens an event where it lives: its own screen, or Nova for a consultation.
/// Ported from `useOpenTimelineEvent`.
void openTimelineEvent(BuildContext context, WidgetRef ref, TimelineEvent event) {
  if (event.conversation != null) {
    ref
        .read(novaUiProvider.notifier)
        .openExistingConversation(event.conversation!.id, event.conversation!.specialitySlug);
  } else if (event.to != null) {
    context.push(event.to!);
  }
}

/// One timeline event. Ported from `TimelineEventRow.tsx`.
class TimelineEventRow extends ConsumerWidget {
  final TimelineEvent event;

  /// Compact = the Home preview: small icon, date · title on one line.
  final bool compact;
  const TimelineEventRow({super.key, required this.event, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final visual = kTimelineKindVisuals[event.kind]!;
    final style = visual.accent.style;
    // A complaint line (consultations) is read-only history with no single
    // thread to reopen — everything else still has its own screen to open.
    final actionable = event.conversation != null || event.to != null;
    const tabular = [FontFeature.tabularFigures()];

    if (compact) {
      final content = Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(8)),
            child: Icon(visual.icon, size: 13.6, color: style.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: Formatters.eventDate(event.date),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabular),
                  ),
                  TextSpan(text: ' · ', style: TextStyle(color: t.ink3)),
                  TextSpan(text: event.title),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.44, height: 1.5, color: t.ink),
            ),
          ),
        ],
      );
      final padded = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      );
      if (!actionable) return padded;
      return InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => openTimelineEvent(context, ref, event),
        child: padded,
      );
    }

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(11)),
            child: Icon(visual.icon, size: 17.6, color: style.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.72,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
                if (event.detail != null && event.detail!.isNotEmpty)
                  Text(
                    event.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Formatters.eventDate(event.date),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.48,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: t.ink2,
              fontFeatures: tabular,
            ),
          ),
          if (actionable) ...[
            const SizedBox(width: 12),
            Icon(PhosphorIconsRegular.caretRight, size: 16, color: t.ink3),
          ],
        ],
      ),
    );
    if (!actionable) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openTimelineEvent(context, ref, event),
      child: row,
    );
  }
}
