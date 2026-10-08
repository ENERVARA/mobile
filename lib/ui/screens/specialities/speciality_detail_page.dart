import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/constants/speciality_images.dart';
import '../../../data/models/speciality.dart';
import '../../../state/nova_ui_provider.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/common.dart';
import '../../widgets/speciality_icon.dart';
import '../../widgets/tone_avatar.dart';

/// A placeholder specialist for the "Doctors Available" list (mirrors the web's
/// `SPECIALIST_DEMO` — the backend only exposes a doctor count).
class _DemoDoctor {
  final String initials;
  final Tone tone;
  final String name;
  final String subtitle;
  final String rating;
  final String nextAvailable;
  const _DemoDoctor(this.initials, this.tone, this.name, this.subtitle, this.rating, this.nextAvailable);
}

const _demoDoctors = <_DemoDoctor>[
  _DemoDoctor('AM', Tone.t1, 'Dr. Anaya Mehta', 'Senior Consultant · 12 yrs', '4.9', 'Today, 4:30 PM'),
  _DemoDoctor('SR', Tone.t2, 'Dr. Sameer Rao', 'Consultant · 9 yrs', '4.7', 'Tomorrow, 11:00 AM'),
  _DemoDoctor('KM', Tone.t3, 'Dr. Kavya Menon', 'Specialist · 7 yrs', '4.8', 'Fri, 2:15 PM'),
];

/// Speciality detail — ported from `SpecialityDetailPage.tsx`: a back pill, a hero
/// card (icon badge, copy, actions over a bleeding photo), Common Conditions
/// chips, and Doctors Available (behind a "booking is ongoing" overlay) — or, for
/// not-yet-enabled specialities, a "Launching soon" waitlist card.
class SpecialityDetailPage extends ConsumerStatefulWidget {
  final String slug;
  const SpecialityDetailPage({super.key, required this.slug});

  @override
  ConsumerState<SpecialityDetailPage> createState() => _SpecialityDetailPageState();
}

class _SpecialityDetailPageState extends ConsumerState<SpecialityDetailPage> {
  @override
  void initState() {
    super.initState();
    // Focus Nova on this speciality (without opening it) so "Ask Nova" opens the
    // right conversation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && isSpecialityEnabled(widget.slug)) {
        ref.read(novaUiProvider.notifier).focusSpeciality(widget.slug);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spec = specialityBySlug(widget.slug);
    if (spec == null) {
      // The web redirects an unknown slug back to the list.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/specialities');
      });
      return const SizedBox.shrink();
    }
    final soon = !isSpecialityEnabled(spec.slug);
    final image = specialityImageAsset(spec.slug, isDark: context.isDark);

    return ShellPage(
      children: [
        // ── Back pill ──
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.canPop() ? context.pop() : context.go('/specialities'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.arrowLeft, size: 13.6, color: t.ink2),
                  const SizedBox(width: 7),
                  Text(
                    'All specialities',
                    style: TextStyle(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Hero ──
        _Hero(spec: spec, soon: soon, image: image, onAskNova: () {
          ref.read(novaUiProvider.notifier).personalize(spec.slug);
        }),
        const SizedBox(height: 26),

        // ── Common Conditions ──
        const _SectionTitle('Common Conditions'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in spec.commonConditions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsRegular.checkCircle, size: 16.8, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Text(
                      c,
                      style: TextStyle(
                        fontSize: 13.76,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Doctors ──
        _SectionTitle(soon ? 'Specialists' : 'Doctors Available'),
        if (soon)
          _LaunchingSoon(specName: spec.name)
        else
          Stack(
            children: [
              Column(
                children: [
                  for (var i = 0; i < _demoDoctors.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _SpecialistCard(doctor: _demoDoctors[i]),
                  ],
                ],
              ),
              const ComingSoon(
                asOverlay: true,
                title: "Doctor's booking is ongoing.",
                description:
                    "We're onboarding real specialists with live availability — booking will unlock here soon.",
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Hero card ───────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Speciality spec;
  final bool soon;
  final String? image;
  final VoidCallback onAskNova;
  const _Hero({required this.spec, required this.soon, required this.image, required this.onAskNova});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // `img-fade-hero … absolute inset-y-0 right-0 w-[48%] bg-cover
          //  bg-[position:60%_center]` — at mobile width the photo sits at 50%.
          if (image != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: c.maxWidth * 0.48,
                    height: c.maxHeight,
                    child: Opacity(
                      opacity: 0.5,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0x00000000), Color(0x66000000), Color(0xFF000000)],
                          stops: [0.0, 0.3, 0.72],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          image!,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.2, 0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (soon) ...[
                  Container(
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
                          style: TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: t.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SpecialityIcon(icon: spec.icon, size: 26, color: AppColors.teal),
                ),
                Text(
                  spec.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.72,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 9),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 44 * 8.8),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      spec.description,
                      style: TextStyle(fontSize: 14.08, height: 1.6, color: t.ink2),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Booking is intentionally disabled ("We're still working on it").
                    Opacity(
                      opacity: 0.6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              soon ? PhosphorIconsRegular.bell : PhosphorIconsRegular.calendarCheck,
                              size: 14.4,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              soon ? 'Join the waitlist' : 'Book a consultation',
                              style: const TextStyle(
                                fontSize: 14.4,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAskNova,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.soft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsRegular.sparkle, size: 14.4, color: AppColors.teal),
                            const SizedBox(width: 8),
                            Text(
                              'Ask Nova about this',
                              style: TextStyle(
                                fontSize: 14.4,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: t.ink,
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
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, right: 2, bottom: 14),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17.6,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.176,
            height: 1.5,
            color: context.tokens.ink,
          ),
        ),
      );
}

class _LaunchingSoon extends StatelessWidget {
  final String specName;
  const _LaunchingSoon({required this.specName});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DashedBox(
      radius: 16,
      width: double.infinity,
      color: t.card,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(PhosphorIconsRegular.clockCountdown, size: 32, color: AppColors.teal),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Launching soon',
                      style: TextStyle(
                        fontSize: 15.36,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        "We're onboarding top $specName specialists. Join the waitlist and we'll let you know the moment it goes live.",
                        style: TextStyle(fontSize: 13.44, height: 1.5, color: t.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AppMessenger.success("You're on the waitlist!"),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsRegular.bell, size: 14.4, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Notify me',
                    style: TextStyle(
                      fontSize: 14.4,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  final _DemoDoctor doctor;
  const _SpecialistCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          ToneAvatar(initials: doctor.initials, tone: doctor.tone, size: 50, fontSize: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: TextStyle(
                    fontSize: 15.36,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    doctor.subtitle,
                    style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsFill.star, size: 12.48, color: AppColors.amber),
                      const SizedBox(width: 4),
                      Text(
                        doctor.rating,
                        style: const TextStyle(
                          fontSize: 12.48,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(PhosphorIconsRegular.clock, size: 11.84, color: t.ink3),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          doctor.nextAvailable,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.84, height: 1.5, color: t.ink3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AppMessenger.success('Booking ${doctor.name}…'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.line),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  fontSize: 13.12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
