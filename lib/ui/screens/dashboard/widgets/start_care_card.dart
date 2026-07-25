import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../data/constants/specialities.dart';
import '../../../widgets/speciality_icon.dart';

/// CTA 1 — "Start new care". Opens a specialist picker; choosing one drops the
/// user into that speciality's Nova assistant. Ported from `StartCareCard.tsx`.
class StartCareCard extends StatelessWidget {
  const StartCareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => showSpecialityPicker(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(PhosphorIconsFill.stethoscope, size: 22, color: AppColors.teal),
            ),
            const SizedBox(height: 16),
            Text(
              'Start new care',
              style: TextStyle(
                fontSize: 17.9,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.18,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Begin a consultation with the right specialist assistant for you.',
              style: TextStyle(fontSize: 13.8, height: 1.5, color: t.ink2),
            ),
            const SizedBox(height: 22),
            // Centred floating CTA
            Container(
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
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(PhosphorIconsBold.arrowRight, size: 15, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Choose a specialist" sheet — the enabled specialities, two per row.
Future<void> showSpecialityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final t = ctx.tokens;
      final specialists = kSpecialities.where((s) => isSpecialityEnabled(s.slug)).toList();
      return Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        // Extra 30px at the bottom so the last row of specialities clears the
        // bottom nav / raised Nova button and stays comfortably tappable.
        padding: EdgeInsets.fromLTRB(18, 12, 18, 48 + MediaQuery.viewPaddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a specialist',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
            ),
            const SizedBox(height: 6),
            Text(
              "Pick the area you'd like help with and Nova connects you to that assistant.",
              style: TextStyle(fontSize: 13.5, height: 1.45, color: t.ink2),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.25,
              children: [
                for (final spec in specialists)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.push('/nova?speciality=${spec.slug}');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.hex(spec.color),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: SpecialityIcon(
                              icon: spec.icon,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              spec.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
