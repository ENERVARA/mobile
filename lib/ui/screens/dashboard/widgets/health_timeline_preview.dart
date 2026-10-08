import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../state/health_records_provider.dart';
import '../../../tour/tour_keys.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';
import '../../health_records/add_to_my_health_flow.dart';
import '../../health_records/widgets/timeline_event_row.dart';

const _previewCount = 3;

/// Home's window into the health record: the latest few events, one tap from the
/// rest (each row opens straight into that specific care, same as the full Health
/// Timeline page). "Add to My Health" lives at the bottom of this card as the one
/// add-a-record entry point on Home. Ported from `HealthTimelinePreview.tsx`.
class HealthTimelinePreview extends ConsumerStatefulWidget {
  const HealthTimelinePreview({super.key});

  @override
  ConsumerState<HealthTimelinePreview> createState() => _HealthTimelinePreviewState();
}

class _HealthTimelinePreviewState extends ConsumerState<HealthTimelinePreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(healthRecordsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final records = ref.watch(healthRecordsProvider);
    final events = records.events;

    return Container(
      key: TourKeys.of('health-timeline'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: dark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.clockCounterClockwise,
                    size: 17.6,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Your health timeline',
                  style: TextStyle(
                    fontSize: 15.68,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
          if (!records.isLoaded)
            Column(
              children: const [
                Skeleton(height: 36, radius: 10),
                SizedBox(height: 8),
                Skeleton(height: 36, radius: 10),
                SizedBox(height: 8),
                Skeleton(height: 36, radius: 10),
              ],
            )
          else if (events.isEmpty)
            Text(
              'Your consultations, lab reports and prescriptions will appear here as your record grows.',
              style: TextStyle(fontSize: 13.44, height: 1.625, color: t.ink2),
            )
          else
            // The web bleeds these rows 8px outward (-mx-2) so their own px-2 lines
            // the icons up with the card's content edge — flush rows are the same
            // layout without the (invisible) bleed.
            Column(
              children: [
                for (final e in events.take(_previewCount))
                  TimelineEventRow(event: e, compact: true),
              ],
            ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/health-timeline'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View your health timeline',
                  style: TextStyle(
                    fontSize: 13.6,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: dark ? AppColors.teal : AppColors.tealD,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  PhosphorIconsRegular.arrowRight,
                  size: 12.8,
                  color: dark ? AppColors.teal : AppColors.tealD,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WebButton(
            label: 'Add to My Health',
            icon: PhosphorIconsFill.plusCircle,
            expand: true,
            radius: 11,
            fontSize: 14.08,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onTap: () => showAddToMyHealthFlow(context),
          ),
        ],
      ),
    );
  }
}
