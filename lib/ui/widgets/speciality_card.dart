import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/context_ext.dart';
import '../../data/constants/specialities.dart';
import '../../data/constants/speciality_images.dart';
import '../../data/models/speciality.dart';

/// Speciality grid card — ported from `src/components/shared/SpecialityCard.tsx`.
/// The hero image bleeds off the right edge at 50% opacity behind the copy
/// (25% for "Coming soon" cards — faded an extra 50%); enabled specialities
/// show "Available", the rest "Coming soon".
class SpecialityCard extends StatelessWidget {
  final Speciality speciality;
  const SpecialityCard({super.key, required this.speciality});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final soon = !isSpecialityEnabled(speciality.slug);
    final image = specialityImageAsset(speciality.slug, isDark: context.isDark);

    return Opacity(
      opacity: soon ? 0.78 : 1,
      child: GestureDetector(
        onTap: () => context.push('/specialities/${speciality.slug}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 158),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (image != null)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -38, // scaled down with the image width below
                  width: MediaQuery.sizeOf(context).width * 0.465, // 0.62 - 25%
                  child: Opacity(
                    // Coming-soon cards get their hero image faded an extra
                    // 50% (0.5 → 0.25) on top of the card-level dimming below.
                    opacity: soon ? 0.25 : 0.5,
                    child: Image.asset(
                      image,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.4, 0),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            speciality.name,
                            style: TextStyle(
                              fontSize: 16.6,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.16,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            speciality.shortDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                          ),
                          // Only "Coming soon" is shown — the "Available" badge
                          // was removed per product request; enabled cards just
                          // read as available by omission.
                          if (soon) ...[
                            const SizedBox(height: 14),
                            const _ComingSoonPill(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: t.ink3, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: t.ink3),
          ),
        ],
      ),
    );
  }
}
