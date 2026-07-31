import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../data/constants/specialities.dart';
import '../../../state/auth_provider.dart';
import '../../../state/onboarding_provider.dart';
import '../../widgets/speciality_card.dart';
import 'widgets/ask_query_card.dart';
import 'widgets/basic_onboarding_sheet.dart';
import 'widgets/resume_care_card.dart';
import 'widgets/start_care_card.dart';

/// Dashboard — ported from `src/features/dashboard/pages/DashboardPage.tsx`.
/// On mobile the two-column grid collapses to a single stacked column:
/// greeting → Start care → Resume care → Specialities (3, static) → Ask a query.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

/// Session-scoped flag mirroring the web's `sessionStorage` guard so the
/// speciality picker only auto-opens once per app launch.
bool _specialityPickerShown = false;

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _basicsShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingProvider.notifier).load();
    });
  }

  /// Bare-minimum H/W modal only during initial onboarding (when user hasn't
  /// set height/weight yet); otherwise the once-per-session speciality picker.
  void _maybeShowIntro(OnboardingUiState onboarding, bool userHasBasics) {
    if (!onboarding.isLoaded || _basicsShown) return;
    // Only show basics modal if user hasn't already filled in height/weight
    if (!userHasBasics) {
      _basicsShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showBasicOnboardingSheet(context);
      });
      return;
    }
    if (!_specialityPickerShown) {
      _specialityPickerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSpecialityPicker(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = ref.watch(authProvider).user;
    final onboarding = ref.watch(onboardingProvider);
    // Only show basics modal if user hasn't set height/weight (permanent check)
    final userHasBasics = (user?.heightCm ?? 0) > 0 && (user?.weightKg ?? 0) > 0;
    _maybeShowIntro(onboarding, userHasBasics);

    final name = user?.firstName.trim() ?? '';
    final firstName = name.isNotEmpty ? name : 'there';

    // "Sunday, July 19, 2026 — let's find the right care for you."
    final dateLine = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    final subtitle = "$dateLine — let's find the right care for you.";

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // ── Greeting ──
          Text(
            'Hello, $firstName 👋',
            style: TextStyle(
              fontSize: 21.6,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.65,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12.8, color: t.ink2)),
          const SizedBox(height: 16),

          // ── Care entry points ──
          const StartCareCard(),
          const SizedBox(height: 16),
          const ResumeCareCard(),

          // ── Specialities ──
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Specialities',
                  style: TextStyle(fontSize: 17.3, fontWeight: FontWeight.w600, color: t.ink),
                ),
                GestureDetector(
                  onTap: () => context.go('/specialities'),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final spec in kSpecialities.take(3)) ...[
            SpecialityCard(speciality: spec),
            const SizedBox(height: 12),
          ],

          // ── Ask a medical query ──
          const SizedBox(height: 10),
          const AskQueryCard(),
        ],
      ),
    );
  }
}
