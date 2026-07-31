import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../state/auth_provider.dart';
import '../../../../state/onboarding_provider.dart';
import '../../../widgets/app_button.dart';

/// The two basics asked at first login. Mirrors `BASIC_QUESTIONS` in
/// `src/constants/onboarding.ts` — age is deliberately not asked (it's derived
/// from `user.dateOfBirth`).
class _BasicQuestion {
  final String fieldName;
  final String label;
  final String unit;
  final int min;
  final int max;
  final int defaultValue;
  const _BasicQuestion(this.fieldName, this.label, this.unit, this.min, this.max, this.defaultValue);
}

const _questions = <_BasicQuestion>[
  _BasicQuestion('height_cm', 'What is your height?', 'cm', 100, 220, 170),
  _BasicQuestion('weight_kg', 'What is your current weight?', 'kg', 30, 200, 70),
];

/// Non-dismissable basics sheet, shown on the dashboard when `hasBasics` is
/// false. Ported from `BasicOnboardingModal.tsx`.
Future<void> showBasicOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BasicOnboardingSheet(),
  );
}

class _BasicOnboardingSheet extends ConsumerStatefulWidget {
  const _BasicOnboardingSheet();

  @override
  ConsumerState<_BasicOnboardingSheet> createState() => _BasicOnboardingSheetState();
}

class _BasicOnboardingSheetState extends ConsumerState<_BasicOnboardingSheet> {
  int _step = 0;
  bool _submitting = false;
  late final Map<String, int> _values = {
    for (final q in _questions) q.fieldName: q.defaultValue,
  };
  late final TextEditingController _controller =
      TextEditingController(text: _values[_questions[0].fieldName].toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _BasicQuestion get _current => _questions[_step];
  bool get _isFirst => _step == 0;
  bool get _isLast => _step == _questions.length - 1;

  void _setValue(String raw) {
    final n = int.tryParse(raw);
    if (n == null) return;
    _values[_current.fieldName] = n.clamp(_current.min, _current.max);
    setState(() {});
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _controller.text = _values[_questions[step].fieldName].toString();
    });
  }

  Future<void> _next() async {
    if (!_isLast) {
      _goTo(_step + 1);
      return;
    }
    setState(() => _submitting = true);
    try {
      final h = _values['height_cm']?.toDouble();
      final w = _values['weight_kg']?.toDouble();
      if (h == null || w == null) {
        AppMessenger.error('Please enter valid height and weight');
        return;
      }
      // Canonical current H/W → users (single source of truth). Do NOT write
      // these to onboardingresponses (that would recreate two sources).
      await ref.read(authProvider.notifier).updateMe({'heightCm': h, 'weightKg': w});
      // Refresh onboarding-derived state so hasBasics (now computed from users)
      // flips true and the dashboard won't re-prompt.
      await ref.read(onboardingProvider.notifier).load();
      if (!mounted) return;
      AppMessenger.success('Profile basics saved');
      Navigator.of(context).pop();
    } catch (e) {
      AppMessenger.error('Failed to save');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Live BMI preview on the weight step, once height is known.
    final showBmi = _current.fieldName == 'weight_kg';
    final bmi = showBmi
        ? computeBmi(
            heightCm: _values['height_cm']?.toDouble(),
            weightKg: _values['weight_kg']?.toDouble(),
          )
        : null;

    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(
          22,
          24,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _questions.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _step ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.teal : t.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              _current.label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: t.ink),
            ),
            const SizedBox(height: 22),
            // Value input
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 128,
                  child: TextField(
                    controller: _controller,
                    onChanged: _setValue,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: t.card,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_current.unit,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: t.ink2)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Range: ${_current.min}–${_current.max} ${_current.unit}',
              style: TextStyle(fontSize: 12, color: t.ink3),
            ),
            if (bmi != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Your BMI: ${bmi.value.toStringAsFixed(1)} (${bmi.category})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.ghost,
                    height: 46,
                    icon: PhosphorIconsBold.arrowLeft,
                    onPressed: (_isFirst || _submitting) ? null : () => _goTo(_step - 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: _isLast ? 'Finish' : 'Next',
                    height: 46,
                    loading: _submitting,
                    icon: _isLast ? PhosphorIconsBold.check : PhosphorIconsBold.arrowRight,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
