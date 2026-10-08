import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/css_shadow.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/care_journey.dart';
import '../../../widgets/common.dart';
import '../../../widgets/entrance.dart';

/// Vertical five-step rail for one complaint: node + connecting line on the
/// left, card on the right, top to bottom. Done steps keep a solid teal border,
/// the current step glows, upcoming steps stay dull. A timestamp shows next to a
/// stage's summary whenever the backend sends one — never fabricated when it
/// doesn't. Ported from `CareJourneyRail.tsx`.
class CareJourneyRail extends StatefulWidget {
  final CareJourney journey;
  const CareJourneyRail({super.key, required this.journey});

  @override
  State<CareJourneyRail> createState() => _CareJourneyRailState();
}

class _CareJourneyRailState extends State<CareJourneyRail> with SingleTickerProviderStateMixin {
  // `journeyGlow` / `journeyNodeGlow`: 2.4s, ease-in-out, infinite — a soft
  // halo that swells and recedes.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> _glow = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stages = widget.journey.stages;
    final doneCount = stages.where((s) => s.status == JourneyStageStatus.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'YOUR CARE JOURNEY',
                style: TextStyle(
                  fontSize: 11.52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0368,
                  height: 1.5,
                  color: t.ink2,
                ),
              ),
              Text(
                '$doneCount of ${stages.length} complete',
                style: TextStyle(
                  fontSize: 12.48,
                  height: 1.5,
                  color: t.ink3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < stages.length; i++)
          _StageRow(stage: stages[i], last: i == stages.length - 1, glow: _glow),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final JourneyStage stage;
  final bool last;
  final Animation<double> glow;
  const _StageRow({required this.stage, required this.last, required this.glow});

  static const _duration = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final meta = kJourneyStageMeta[stage.key]!;
    final status = stage.status;
    final done = status == JourneyStageStatus.done;
    final active = status == JourneyStageStatus.active;
    final pending = status == JourneyStageStatus.pending;

    // ── Node ──
    Widget node = AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final g = active ? glow.value : 0.0;
        return AnimatedContainer(
          duration: _duration,
          curve: Curves.ease,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? (dark ? const Color(0xFF123A36) : const Color(0xFFDFF5F2))
                : active
                    ? AppColors.teal
                    : t.soft,
            border: pending ? Border.all(color: t.line) : null,
            boxShadow: active
                ? [
                    cssShadow(
                      AppColors.teal.withValues(alpha: _lerp(.22, .30, g)),
                      spread: _lerp(3, 5, g),
                    ),
                    cssShadow(
                      AppColors.teal.withValues(alpha: _lerp(.35, .55, g)),
                      blur: _lerp(8, 12, g),
                      spread: _lerp(1, 2, g),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            done ? PhosphorIconsBold.check : (pending ? meta.icon : meta.iconBold),
            size: 15.2,
            color: done ? AppColors.teal : (active ? Colors.white : t.ink3),
          ),
        );
      },
    );

    // ── Card ──
    final summary = stage.summary;
    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              meta.title,
              style: TextStyle(
                fontSize: 14.08,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: pending ? t.ink2 : t.ink,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stage.timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      Formatters.dateTimeIso(stage.timestamp),
                      style: TextStyle(
                        fontSize: 11.2,
                        height: 1.5,
                        color: t.ink3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if (active) _InProgressPill(dark: dark),
                if (done)
                  const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 10.88,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppColors.teal,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: summary != null
              ? Entrance.up(
                  // A new summary replays the entrance (`key={stage.summary}`).
                  key: ValueKey(summary),
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12.8,
                      height: 1.375,
                      color: active ? t.ink : t.ink2,
                    ),
                  ),
                )
              : Text(
                  meta.placeholder,
                  style: TextStyle(fontSize: 12.48, height: 1.375, color: t.ink3),
                ),
        ),
      ],
    );

    Widget card;
    if (pending) {
      card = Opacity(
        opacity: 0.55,
        child: DashedBox(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: SizedBox(width: double.infinity, child: cardBody),
        ),
      );
    } else {
      card = AnimatedBuilder(
        animation: glow,
        builder: (context, _) {
          final g = active ? glow.value : 0.0;
          return AnimatedContainer(
            duration: _duration,
            curve: Curves.ease,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? AppColors.teal : AppColors.teal.withValues(alpha: 0.55)),
              boxShadow: active
                  ? [
                      cssShadow(AppColors.teal.withValues(alpha: _lerp(.35, .55, g)), spread: 1),
                      cssShadow(
                        AppColors.teal.withValues(alpha: _lerp(.35, .5, g)),
                        blur: _lerp(10, 16, g),
                        spread: _lerp(-2, 0, g),
                      ),
                    ]
                  : const [],
            ),
            child: cardBody,
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Node + connector. The connector runs from under the node to the
            // top of the next row (`bottom-[-12px] top-8 w-[2px]`).
            SizedBox(
              width: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (!last)
                    Positioned(
                      top: 32,
                      bottom: -12,
                      width: 2,
                      child: AnimatedContainer(
                        duration: _duration,
                        decoration: BoxDecoration(
                          color: done ? AppColors.teal : t.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  node,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: card),
          ],
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// "• In progress" — a pulsing teal dot (`animate-pulse`) in a soft teal pill.
class _InProgressPill extends StatefulWidget {
  final bool dark;
  const _InProgressPill({required this.dark});

  @override
  State<_InProgressPill> createState() => _InProgressPillState();
}

class _InProgressPillState extends State<_InProgressPill> with SingleTickerProviderStateMixin {
  // Tailwind `pulse`: 2s cubic-bezier(.4,0,.6,1) infinite, opacity 1 → .5 → 1.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Opacity(
              opacity: 1 - 0.5 * const Cubic(0.4, 0, 0.6, 1).transform(_c.value),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'In progress',
            style: TextStyle(
              fontSize: 10.88,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: widget.dark ? AppColors.teal : AppColors.tealD,
            ),
          ),
        ],
      ),
    );
  }
}
