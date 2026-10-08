import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/timeline.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';
import 'timeline_event_row.dart';

/// "What happened to me over time?" — every dated health event, newest first, by
/// month. Ported from `TimelineTab.tsx`.
class TimelineTab extends StatelessWidget {
  final List<TimelineEvent> events;
  final bool isLoaded;
  final VoidCallback onAdd;
  const TimelineTab({super.key, required this.events, required this.isLoaded, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (!isLoaded) {
      return Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const Skeleton(height: 62, radius: 14),
          ],
        ],
      );
    }

    if (events.isEmpty) {
      return DashedBox(
        radius: 18,
        width: double.infinity,
        color: t.card,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 22.4, color: AppColors.teal),
            ),
            Text(
              'Your timeline is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(
                'Consultations, lab reports, prescriptions and documents appear here once they are part of your record.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
              ),
            ),
            const SizedBox(height: 20),
            WebButton(
              label: 'Add to My Health',
              icon: PhosphorIconsFill.plusCircle,
              onTap: onAdd,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ],
        ),
      );
    }

    // Group by month, newest first (insertion order of the sorted event list).
    final groups = <String, List<TimelineEvent>>{};
    for (final e in events) {
      final d = Formatters.tryParse(e.date);
      final key = d == null ? '' : Formatters.monthYear(d);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return Column(
      children: [
        for (final entry in groups.entries) ...[
          _MonthSection(month: entry.key, items: entry.value),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _MonthSection extends StatelessWidget {
  final String month;
  final List<TimelineEvent> items;
  const _MonthSection({required this.month, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            month.toUpperCase(),
            style: TextStyle(
              fontSize: 12.16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.216,
              height: 1.5,
              color: t.ink3,
            ),
          ),
        ),
        // A thin rail ties the month's events together as one sequence.
        Stack(
          children: [
            Positioned(
              left: 5,
              top: 12,
              bottom: 12,
              child: Container(
                width: 2,
                decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TimelineEventRow(event: items[i]),
                        Positioned(
                          left: -16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                shape: BoxShape.circle,
                                border: Border.all(color: t.card, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
