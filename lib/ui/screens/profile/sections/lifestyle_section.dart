import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../state/health_profile_provider.dart';
import '../../../widgets/segmented_control.dart';
import '../widgets/profile_parts.dart';

const _dietOptions = <({String value, String label})>[
  (value: 'vegetarian', label: 'Vegetarian'),
  (value: 'non_veg', label: 'Non-Veg'),
  (value: 'vegan', label: 'Vegan'),
  (value: 'eggetarian', label: 'Eggetarian'),
];

const _yesNoSometimes = <SegmentOption<String>>[
  SegmentOption('yes', 'Yes'),
  SegmentOption('no', 'No'),
  SegmentOption('sometimes', 'Sometimes'),
];

/// Diet / exercise / alcohol / smoking + sleep & water sliders — directly
/// editable with debounced autosave. Ported from `LifestyleSection.tsx`.
class LifestyleSection extends ConsumerStatefulWidget {
  const LifestyleSection({super.key});

  @override
  ConsumerState<LifestyleSection> createState() => _LifestyleSectionState();
}

class _LifestyleSectionState extends ConsumerState<LifestyleSection> {
  Timer? _debounce;
  double? _sleepHours;
  double? _waterCups;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _persist(Map<String, dynamic> patch) {
    ref.read(healthProfileProvider.notifier).saveLifestyle(patch);
  }

  void _persistDebounced(Map<String, dynamic> patch) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _persist(patch));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lifestyle = ref.watch(healthProfileProvider).lifestyle;
    final sleep = _sleepHours ?? (lifestyle.sleepHours?.toDouble() ?? 7);
    final water = _waterCups ?? (lifestyle.waterCups?.toDouble() ?? 6);

    return InfoCard(
      icon: PhosphorIconsRegular.forkKnife,
      title: 'Lifestyle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diet
          Text('Diet', style: TextStyle(fontSize: 13.8, color: t.ink2)),
          const SizedBox(height: 6),
          LabeledSelect(
            label: '',
            value: lifestyle.diet,
            placeholder: 'Not set',
            options: _dietOptions,
            onChanged: (v) => _persist({'diet': v}),
          ),
          const SizedBox(height: 16),

          _Row(
            label: 'Exercise',
            child: SegmentedControl<String>(
              options: _yesNoSometimes,
              value: lifestyle.exercise,
              onChanged: (v) => _persist({'exercise': v}),
            ),
          ),
          _Row(
            label: 'Alcohol',
            child: SegmentedControl<String>(
              options: _yesNoSometimes,
              value: lifestyle.alcohol,
              onChanged: (v) => _persist({'alcohol': v}),
            ),
          ),
          _Row(
            label: 'Smoking',
            child: SegmentedControl<String>(
              options: _yesNoSometimes,
              value: lifestyle.smoking,
              onChanged: (v) => _persist({'smoking': v}),
            ),
          ),

          // Sleep
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sleep', style: TextStyle(fontSize: 13.8, color: t.ink2)),
              Text('${sleep.toStringAsFixed(sleep % 1 == 0 ? 0 : 1)}h',
                  style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w600, color: t.ink)),
            ],
          ),
          Slider(
            value: sleep.clamp(0, 12),
            min: 0,
            max: 12,
            divisions: 24,
            activeColor: AppColors.teal,
            onChanged: (v) => setState(() => _sleepHours = v),
            onChangeEnd: (v) => _persistDebounced({'sleepHours': v}),
          ),
          if (sleep < 6)
            Text(
              'Below the 7–9h range doctors typically recommend.',
              style: const TextStyle(fontSize: 11.8, color: AppColors.coral),
            ),

          // Water
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Water intake', style: TextStyle(fontSize: 13.8, color: t.ink2)),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '${water.toInt()} cups ',
                    style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w600, color: t.ink),
                  ),
                  TextSpan(
                    text: '(~${water.toInt() * 250}ml)',
                    style: TextStyle(fontSize: 13.8, color: t.ink3),
                  ),
                ]),
              ),
            ],
          ),
          Slider(
            value: water.clamp(0, 15),
            min: 0,
            max: 15,
            divisions: 15,
            activeColor: AppColors.teal,
            onChanged: (v) => setState(() => _waterCups = v),
            onChangeEnd: (v) => _persistDebounced({'waterCups': v.toInt()}),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13.8, color: t.ink2)),
          const SizedBox(height: 6),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
        ],
      ),
    );
  }
}
