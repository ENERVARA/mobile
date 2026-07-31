import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/constants/speciality_images.dart';
import '../../../data/models/speciality.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/speciality_icon.dart';

/// A placeholder specialist for the "Doctors Available" list (mirrors the web's
/// `SPECIALIST_DEMO` — the backend only exposes a doctor count).
class _DemoDoctor {
  final String initials;
  final String name;
  final String subtitle;
  final String rating;
  final String nextAvailable;
  final List<Color> tone;
  const _DemoDoctor(this.initials, this.name, this.subtitle, this.rating, this.nextAvailable, this.tone);
}

const _demoDoctors = <_DemoDoctor>[
  _DemoDoctor('AM', 'Dr. Anaya Mehta', 'Senior Consultant · 12 yrs', '4.9', 'Today, 4:30 PM',
      [AppColors.teal, AppColors.cyan]),
  _DemoDoctor('SR', 'Dr. Sameer Rao', 'Consultant · 9 yrs', '4.7', 'Tomorrow, 11:00 AM',
      [AppColors.lav, Color(0xFFB79BFF)]),
  _DemoDoctor('KM', 'Dr. Kavya Menon', 'Specialist · 7 yrs', '4.8', 'Fri, 2:15 PM',
      [AppColors.coral, Color(0xFFF7996B)]),
];

/// Speciality detail — ported from `SpecialityDetailPage.tsx`. A hero card
/// (icon badge + aligned bleeding image + actions), Common Conditions chips,
/// Doctors Available (behind a "booking coming soon" overlay), Available Tests.
class SpecialityDetailPage extends StatelessWidget {
  final String slug;
  const SpecialityDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spec = specialityBySlug(slug);
    if (spec == null) {
      return Center(child: Text('Speciality not found', style: TextStyle(color: t.ink2)));
    }
    final soon = !isSpecialityEnabled(slug);
    final image = specialityImageAsset(slug, isDark: context.isDark);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // ── Back pill ──
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : context.go('/specialities'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.arrowLeft, size: 15, color: t.ink2),
                    const SizedBox(width: 7),
                    Text('All specialities',
                        style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w600, color: t.ink2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Hero card ──
          _Hero(spec: spec, soon: soon, image: image),
          const SizedBox(height: 24),

          // ── Common Conditions ──
          _SectionTitle('Common Conditions'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in spec.commonConditions)
                _Chip(icon: PhosphorIconsRegular.checkCircle, label: c, strong: true),
            ],
          ),
          const SizedBox(height: 26),

          // ── Doctors Available ──
          _SectionTitle(soon ? 'Specialists' : 'Doctors Available'),
          const SizedBox(height: 12),
          if (soon)
            _WaitlistCard(specName: spec.name)
          else
            Stack(
              children: [
                Column(
                  children: [
                    for (final d in _demoDoctors) ...[
                      _DoctorCard(doctor: d),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
                const Positioned.fill(
                  child: ComingSoon(
                    asOverlay: true,
                    title: "Doctor's booking is ongoing.",
                    description:
                        "We're onboarding real specialists with live availability — booking will unlock here soon.",
                  ),
                ),
              ],
            ),
          const SizedBox(height: 26),

          // ── Available Tests ──
          _SectionTitle('Available Tests'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final test in spec.availableTests)
                _Chip(icon: PhosphorIconsRegular.flask, label: test, strong: false),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Hero card ───────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Speciality spec;
  final bool soon;
  final String? image;
  const _Hero({required this.spec, required this.soon, required this.image});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Bleeding image, faded on its left edge, aligned to the right.
          if (image != null)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: MediaQuery.sizeOf(context).width * 0.5,
              child: Opacity(
                // Coming-soon specialities get their hero image faded an
                // extra 50% (0.5 → 0.25), matching the grid card treatment.
                opacity: soon ? 0.25 : 0.5,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.55],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(image!, fit: BoxFit.cover, alignment: const Alignment(0.2, 0)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.66),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (soon) ...[
                    _ComingSoonTag(),
                    const SizedBox(height: 12),
                  ],
                  // Icon badge
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SpecialityIcon(icon: spec.icon, size: 24, color: AppColors.teal),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    spec.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spec.description,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: t.ink2),
                  ),
                  const SizedBox(height: 16),
                  // Primary (disabled) booking action
                  _PrimaryButton(
                    icon: soon ? PhosphorIconsFill.bell : PhosphorIconsFill.calendarCheck,
                    label: soon ? 'Join the waitlist' : 'Book a consultation',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          icon: PhosphorIconsFill.sparkle,
                          label: 'Ask Nova',
                          onTap: soon ? null : () => context.push('/nova?speciality=${spec.slug}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GhostButton(
                          icon: PhosphorIconsRegular.userCircle,
                          label: 'Health Profile',
                          onTap: () => context.go('/profile'),
                        ),
                      ),
                    ],
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

class _ComingSoonTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: t.ink3, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Coming soon',
              style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: t.ink3)),
        ],
      ),
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PrimaryButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    // Booking is intentionally disabled ("We're still working on it").
    return Opacity(
      opacity: 0.6,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _GhostButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.teal),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small pieces ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17.6,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.16,
            color: context.tokens.ink,
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool strong;
  const _Chip({required this.icon, required this.label, required this.strong});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.4,
              fontWeight: strong ? FontWeight.w500 : FontWeight.w500,
              color: strong ? t.ink : t.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final _DemoDoctor doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: doctor.tone,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(doctor.initials,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(doctor.name,
                    style: TextStyle(fontSize: 14.6, fontWeight: FontWeight.w600, color: t.ink)),
                const SizedBox(height: 1),
                Text(doctor.subtitle, style: TextStyle(fontSize: 12, color: t.ink2)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(PhosphorIconsFill.star, size: 12, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text(doctor.rating,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber)),
                    const SizedBox(width: 12),
                    Icon(PhosphorIconsRegular.clock, size: 12, color: t.ink3),
                    const SizedBox(width: 4),
                    Text(doctor.nextAvailable, style: TextStyle(fontSize: 11.5, color: t.ink3)),
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

class _WaitlistCard extends StatelessWidget {
  final String specName;
  const _WaitlistCard({required this.specName});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line, style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsDuotone.clockCountdown, size: 28, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Launching soon',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink)),
                    const SizedBox(height: 3),
                    Text(
                      "We're onboarding top $specName specialists. We'll let you know the moment it goes live.",
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
