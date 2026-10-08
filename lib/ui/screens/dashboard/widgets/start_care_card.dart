import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../tour/tour_keys.dart';
import 'speciality_pickers.dart';

/// CTA 1 — Start a new care / consultation. Opens a specialist picker; choosing
/// one redirects into that speciality's assistant (Nova, focused). Ported from
/// `StartCareCard.tsx` at mobile width (`min-h-[240px]`).
class StartCareCard extends ConsumerStatefulWidget {
  const StartCareCard({super.key});

  @override
  ConsumerState<StartCareCard> createState() => _StartCareCardState();
}

class _StartCareCardState extends ConsumerState<StartCareCard> with SingleTickerProviderStateMixin {
  // `.animate-float-btn` — translateY 0 → -6px → 0 over 3s ease-in-out.
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Material(
      key: TourKeys.of('start-care'),
      color: t.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showStartCarePicker(context, ref),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 240 - 46),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(PhosphorIconsFill.stethoscope, size: 22.4, color: AppColors.teal),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start new care',
                    style: TextStyle(
                      fontSize: 17.92,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1792,
                      height: 1.5,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Begin a consultation with the right specialist assistant for you.',
                    style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
                  ),
                  // Centred floating CTA — the 12px gap guarantees clearance above
                  // the pill even at the top of its float-bob.
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _float,
                        builder: (context, child) {
                          final k = reduceMotion ? 0.0 : Curves.easeInOut.transform(_float.value);
                          return Transform.translate(offset: Offset(0, -6 * k), child: child);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teal.withValues(alpha: 0.3),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Start consultation',
                                style: TextStyle(
                                  fontSize: 14.4,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(PhosphorIconsBold.arrowRight, size: 14.4, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
