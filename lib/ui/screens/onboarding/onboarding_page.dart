import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/logo.dart';
import '../../widgets/segmented_control.dart';

/// Mandatory post-signup onboarding. A clean welcome + a short form that
/// collects the two profile essentials — date of birth and sex — then calls
/// `completeOnboarding()`. The router's redirect gate ([app_router.dart]) sends
/// the user to `/dashboard` the moment `onboardingCompleted` flips to true, so
/// there's no manual navigation here.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

const _sexOptions = <SegmentOption<String>>[
  SegmentOption('female', 'Female'),
  SegmentOption('male', 'Male'),
  SegmentOption('intersex', 'Intersex'),
  SegmentOption('prefer_not_to_say', 'Prefer not to say'),
];

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  DateTime? _dob;
  String? _sex;
  bool _submitting = false;

  bool get _canSubmit => _dob != null && _sex != null;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).updateMe({
        'dateOfBirth': _iso(_dob!),
        'sex': _sex,
      });
      // Router redirects to /dashboard once this flips onboardingCompleted.
      await ref.read(authProvider.notifier).completeOnboarding();
    } catch (_) {
      // updateMe / completeOnboarding surface their own toast via the
      // API client's error interceptor.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = ref.watch(authProvider).user;
    final ageIso = _dob != null ? _iso(_dob!) : null;
    final age = Formatters.ageFromDob(ageIso);

    return Scaffold(
      backgroundColor: t.appBg,
      body: Column(
        children: [
          _Header(name: user?.firstName ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Just two essentials so Nova and your care team can '
                    'personalise your health guidance.',
                    style: TextStyle(fontSize: 14, height: 1.45, color: t.ink2),
                  ),
                  const SizedBox(height: 28),

                  // ── Date of birth ──
                  _FieldLabel('Date of birth'),
                  const SizedBox(height: 8),
                  _DobField(dob: _dob, onTap: _pickDob),
                  if (age != null) ...[
                    const SizedBox(height: 10),
                    _AgePill(age: age),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'We use this to tailor recommendations to your age.',
                    style: TextStyle(fontSize: 12.5, color: t.ink3),
                  ),
                  const SizedBox(height: 26),

                  // ── Sex ──
                  _FieldLabel('Which best describes you?'),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedControl<String>(
                      options: _sexOptions,
                      value: _sex,
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Helps us personalise health guidance for you.',
                    style: TextStyle(fontSize: 12.5, color: t.ink3),
                  ),
                  const SizedBox(height: 36),

                  AppButton(
                    label: 'Get started',
                    variant: AppButtonVariant.gradient,
                    icon: Icons.check_rounded,
                    loading: _submitting,
                    onPressed: _canSubmit ? _submit : null,
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

/// Brand-gradient hero at the top of the page — white Logo + welcome copy.
class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    final topPad = context.viewPadding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 28, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Logo(size: 30, white: true),
              const SizedBox(width: 10),
              const Text(
                'Enervara',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            name.trim().isEmpty ? 'Welcome!' : 'Welcome, ${name.trim()}!',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Let's set up your health profile.",
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: context.tokens.ink,
        ),
      );
}

/// Tappable input-styled field that opens the native date picker.
class _DobField extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onTap;
  const _DobField({required this.dob, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasValue = dob != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 20, color: t.ink3),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasValue ? Formatters.dateMedium(dob!) : 'Select your date of birth',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? t.ink : t.ink3,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgePill extends StatelessWidget {
  final int age;
  const _AgePill({required this.age});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          "You're $age years old",
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.tealD,
          ),
        ),
      );
}
