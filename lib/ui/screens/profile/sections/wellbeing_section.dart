import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../state/health_profile_provider.dart';
import '../../../widgets/segmented_control.dart';
import '../widgets/profile_parts.dart';

const _relaxationOptions = <SegmentOption<String>>[
  SegmentOption('daily', 'Daily'),
  SegmentOption('weekly', 'Weekly'),
  SegmentOption('occasionally', 'Occasionally'),
  SegmentOption('never', 'Never'),
];

class _SliderSpec {
  final String key;
  final String label;
  final String anchors;
  const _SliderSpec(this.key, this.label, this.anchors);
}

const _sliders = <_SliderSpec>[
  _SliderSpec('overallMood', 'Overall Mood', '1 = Very low • 10 = Excellent'),
  _SliderSpec('stressLevel', 'Stress Level', '1 = Very relaxed • 10 = Extremely stressed'),
  _SliderSpec('energyLevel', 'Energy Level', '1 = Constantly fatigued • 10 = Highly energetic'),
  _SliderSpec('socialConnectedness', 'Social Connectedness', '1 = Feel isolated • 10 = Feel well supported'),
  _SliderSpec('workAcademicPressure', 'Work / Academic Pressure', '1 = No pressure • 10 = Overwhelming pressure'),
];

/// Mental, emotional and social wellbeing — 5 sliders + relaxation practices,
/// debounced autosave. Ported from `WellbeingSection.tsx`.
class WellbeingSection extends ConsumerStatefulWidget {
  const WellbeingSection({super.key});

  @override
  ConsumerState<WellbeingSection> createState() => _WellbeingSectionState();
}

class _WellbeingSectionState extends ConsumerState<WellbeingSection> {
  Timer? _debounce;
  final Map<String, double> _local = {};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _persistDebounced(Map<String, dynamic> patch) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(healthProfileProvider.notifier).saveWellbeing(patch);
    });
  }

  double _valueFor(String key) {
    if (_local.containsKey(key)) return _local[key]!;
    final w = ref.read(healthProfileProvider).wellbeing;
    final stored = switch (key) {
      'overallMood' => w.overallMood,
      'stressLevel' => w.stressLevel,
      'energyLevel' => w.energyLevel,
      'socialConnectedness' => w.socialConnectedness,
      'workAcademicPressure' => w.workAcademicPressure,
      _ => null,
    };
    return stored?.toDouble() ?? 5;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wellbeing = ref.watch(healthProfileProvider).wellbeing;

    return InfoCard(
      icon: PhosphorIconsRegular.smiley,
      title: 'Mental & Emotional Wellbeing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in _sliders) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(s.label, style: TextStyle(fontSize: 13.8, color: t.ink2)),
                ),
                Text(
                  _valueFor(s.key).toInt().toString(),
                  style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w600, color: t.ink),
                ),
              ],
            ),
            Slider(
              value: _valueFor(s.key).clamp(1, 10),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.teal,
              onChanged: (v) => setState(() => _local[s.key] = v),
              onChangeEnd: (v) => _persistDebounced({s.key: v.toInt()}),
            ),
            Text(s.anchors, style: TextStyle(fontSize: 11.2, color: t.ink3)),
            const SizedBox(height: 14),
          ],
          Text('Relaxation practices', style: TextStyle(fontSize: 13.8, color: t.ink2)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedControl<String>(
              options: _relaxationOptions,
              value: wellbeing.relaxationPractices,
              onChanged: (v) =>
                  ref.read(healthProfileProvider.notifier).saveWellbeing({'relaxationPractices': v}),
            ),
          ),
        ],
      ),
    );
  }
}
