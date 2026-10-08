import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../data/constants/specialities.dart';
import '../../../data/services/location_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/onboarding_provider.dart';
import '../../tour/product_tour.dart';
import '../../tour/tour_storage.dart';
import '../../widgets/common.dart';
import '../../widgets/speciality_card.dart';
import 'widgets/basic_onboarding_sheet.dart';
import 'widgets/health_timeline_preview.dart';
import 'widgets/location_access_sheet.dart';
import 'widgets/nearby_doctors_card.dart';
import 'widgets/resume_care_card.dart';
import 'widgets/speciality_pickers.dart';
import 'widgets/start_care_card.dart';

/// Home — ported from `features/dashboard/pages/DashboardPage.tsx`. At mobile
/// width the two-column grid collapses to a single stacked column:
/// greeting → Start care → Resume care → Explore new care (6 specialities) →
/// Doctors → Your health timeline.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _scroll = ScrollController();
  bool _flowStarted = false;
  bool _specialityPickerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    // Leaving the dashboard mid-tour just stops it; it isn't recorded as seen.
    abortProductTour();
    _scroll.dispose();
    super.dispose();
  }

  /// First-visit dialogs, in the web's order, one at a time so a brand-new
  /// patient is never shown two overlays at once: the height/weight dialog →
  /// the product tour (new accounts) → the location prompt → the speciality
  /// picker (once per session).
  Future<void> _introFlow() async {
    if (!mounted) return;

    // Never show any of these on an unauthenticated or still-hydrating
    // session. The router already keeps DashboardPage off-screen until
    // auth.isAuthenticated is true, but a belt-and-braces check here means
    // this flow can never fire on a stale/incomplete auth state even if the
    // guard above it ever changes.
    final auth = ref.read(authProvider);
    if (!auth.isHydrated || !auth.isAuthenticated || auth.user == null) return;
    final showLoginIntro = auth.isFreshLogin;
    if (!showLoginIntro) return;
    ref.read(authProvider.notifier).consumeFreshLogin();

    // 1. Bare-minimum H/W dialog whenever onboarding loaded but basics unanswered.
    var user = ref.read(authProvider).user;
    final hasBasics = (user?.heightCm ?? 0) > 0 && (user?.weightKg ?? 0) > 0;
    if (!hasBasics) {
      await showBasicOnboardingSheet(context);
      if (!mounted) return;
    }

    // 2. First-run product tour — goes right after the height/weight dialog and
    // BEFORE the location and speciality dialogs, which wait for it.
    user = ref.read(authProvider).user;
    if (user != null && await shouldAutoStartTour(user.id, user.createdAt)) {
      // Give the page a beat to paint with nothing else on screen.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await runProductTour(context, ref, scrollController: _scroll);
      if (!mounted) return;
    }

    // 3. Location consent, asked once ever (the mobile app's own prompt).
    final decided = await LocationService.instance.hasDecided();
    if (!mounted) return;
    if (!decided) {
      await showLocationAccessSheet(context);
      if (!mounted) return;
    }

    // 4. Speciality picker once after a successful login.
    if (!_specialityPickerShown) {
      _specialityPickerShown = true;
      await showSpecialityPickerModal(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = ref.watch(authProvider).user;
    final onboarding = ref.watch(onboardingProvider);

    // Kick the intro flow off once, as soon as onboarding state is known.
    if (onboarding.isLoaded && !_flowStarted) {
      _flowStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _introFlow());
    }

    final name = user?.firstName.trim() ?? '';
    final firstName = name.isNotEmpty ? name : 'there';

    // "Wednesday, October 7, 2026 — let's find the right care for you."
    final subtitle =
        "${DateFormat('EEEE, MMMM d, y').format(DateTime.now())} — let's find the right care for you.";

    return ShellPage(
      controller: _scroll,
      children: [
        // ── Greeting ──
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName 👋',
                style: TextStyle(
                  fontSize: 21.6,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.648,
                  height: 1.5,
                  color: t.ink,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                ),
              ),
            ],
          ),
        ),

        // ── Care entry points ──
        const StartCareCard(),
        const SizedBox(height: 16),
        const ResumeCareCard(),

        // ── Explore new care ──
        Padding(
          padding: const EdgeInsets.only(
            top: 22,
            bottom: 12,
            left: 2,
            right: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore new care',
                style: TextStyle(
                  fontSize: 17.28,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: t.ink,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/specialities'),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13.28,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < 6 && i < kSpecialities.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          SpecialityCard(speciality: kSpecialities[i]),
        ],

        // ── Doctors ──
        const SizedBox(height: 22),
        const NearbyDoctorsCard(),

        // ── Health timeline (the web's right-rail `aside`, stacked below) ──
        const SizedBox(height: 20),
        const HealthTimelinePreview(),
      ],
    );
  }
}
