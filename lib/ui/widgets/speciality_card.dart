import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../../data/constants/specialities.dart';
import '../../data/constants/speciality_images.dart';
import '../../data/models/speciality.dart';

/// Speciality grid card (redesign). Ported from `SpecialityCard.tsx`: a hero
/// photo bleeds in from the right edge at 50% opacity behind the copy;
/// enabled specialities show "Available", the rest "Coming soon" (card at 78%).
class SpecialityCard extends StatelessWidget {
  final Speciality speciality;
  const SpecialityCard({super.key, required this.speciality});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final soon = !isSpecialityEnabled(speciality.slug);
    final image = specialityImageAsset(speciality.slug, isDark: dark);

    return Opacity(
      opacity: soon ? 0.78 : 1,
      child: Material(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/specialities/${speciality.slug}'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 158),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (image != null)
                  // `absolute inset-y-0 right-[-50px] w-[62%] bg-cover
                  //  bg-[position:70%_center] opacity-50`
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: -50,
                            width: c.maxWidth * 0.62,
                            child: Opacity(
                              opacity: 0.5,
                              child: Image.asset(
                                image,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0.4, 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder: (context, c) => ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth * 0.72),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              speciality.name,
                              style: TextStyle(
                                fontSize: 16.64,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1664,
                                height: 1.5,
                                color: t.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              speciality.shortDescription,
                              style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                            ),
                            const SizedBox(height: 14),
                            _StatusPill(soon: soon),
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool soon;
  const _StatusPill({required this.soon});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final bg = soon ? t.soft : AppColors.teal.withValues(alpha: 0.12);
    final fg = soon ? t.ink3 : (dark ? AppColors.teal : AppColors.tealD);
    final dot = soon ? t.ink3 : AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            soon ? 'Coming soon' : 'Available',
            style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, height: 1.5, color: fg),
          ),
        ],
      ),
    );
  }
}
