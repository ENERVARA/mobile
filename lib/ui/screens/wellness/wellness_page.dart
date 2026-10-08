import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/accent.dart';
import '../../../core/theme/context_ext.dart';
import '../../../state/health_profile_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import '../profile/sections/lifestyle_section.dart';
import '../profile/sections/wellbeing_section.dart';

String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class _Snapshot {
  final String label;
  final String? value;
  final IconData icon;
  final Accent accent;
  const _Snapshot(this.label, this.value, this.icon, this.accent);
}

/// Everyday wellness — habits and how the patient is feeling. Ported from
/// `WellnessPage.tsx`. Both sections are the same live, autosaving
/// health-profile modules used elsewhere, backed by one provider, so an edit here
/// is the same edit everywhere.
class WellnessPage extends ConsumerStatefulWidget {
  const WellnessPage({super.key});

  @override
  ConsumerState<WellnessPage> createState() => _WellnessPageState();
}

class _WellnessPageState extends ConsumerState<WellnessPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(healthProfileProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final health = ref.watch(healthProfileProvider);
    final lifestyle = health.lifestyle;
    final wellbeing = health.wellbeing;

    final snapshot = <_Snapshot>[
      _Snapshot(
        'Sleep',
        lifestyle.sleepHours != null ? '${_num(lifestyle.sleepHours!)} h / night' : null,
        PhosphorIconsFill.moonStars,
        Accent.lav,
      ),
      _Snapshot(
        'Water',
        lifestyle.waterCups != null ? '${_num(lifestyle.waterCups!)} cups / day' : null,
        PhosphorIconsFill.drop,
        Accent.cyan,
      ),
      _Snapshot(
        'Mood',
        wellbeing.overallMood != null ? '${_num(wellbeing.overallMood!)} / 10' : null,
        PhosphorIconsFill.smiley,
        Accent.teal,
      ),
      _Snapshot(
        'Stress',
        wellbeing.stressLevel != null ? '${_num(wellbeing.stressLevel!)} / 10' : null,
        PhosphorIconsFill.lightning,
        Accent.amber,
      ),
    ];

    return ShellPage(
      children: [
        const PageHeader(
          title: 'Wellness',
          subtitle: "Your everyday habits and how you're feeling.",
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: LayoutBuilder(
            builder: (context, c) {
              // grid-cols-2 gap-3 at mobile width
              final w = (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in snapshot)
                    SizedBox(
                      width: w,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.line),
                        ),
                        child: Row(
                          children: [
                            AccentIconBox(
                              icon: s.icon,
                              accent: s.accent,
                              size: 40,
                              radius: 11,
                              iconSize: 18.4,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11.84,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.7104,
                                      height: 1.5,
                                      color: t.ink3,
                                    ),
                                  ),
                                  Text(
                                    !health.isLoaded ? '…' : (s.value ?? 'Not recorded'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.2,
                                      fontWeight: health.isLoaded && s.value == null
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                      height: 1.5,
                                      color: health.isLoaded && s.value == null ? t.ink3 : t.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const LifestyleSection(),
        const SizedBox(height: 16),
        const WellbeingSection(),
      ],
    );
  }
}
