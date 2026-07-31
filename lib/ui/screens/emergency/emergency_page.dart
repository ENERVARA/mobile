import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';

/// Emergency — ported from `src/features/emergency/pages/EmergencyPage.tsx`:
/// hero call button (with the confirm modal), emergency contacts, the user's
/// own contact, first-aid quick reference, and find-nearest-hospital.
class EmergencyPage extends ConsumerWidget {
  const EmergencyPage({super.key});

  static const _contacts = [
    (label: 'Emergency Services', number: AppConfig.emergencyNumber, icon: PhosphorIconsDuotone.ambulance, color: AppColors.danger),
    (label: 'Ambulance', number: AppConfig.ambulanceNumber, icon: PhosphorIconsDuotone.ambulance, color: AppColors.danger),
    (label: 'Poison Control', number: '1-800-222-1222', icon: PhosphorIconsDuotone.warning, color: AppColors.amber),
    (label: 'Mental Health Crisis', number: '988', icon: PhosphorIconsDuotone.phone, color: AppColors.lav),
  ];

  static const _firstAid = [
    (
      title: 'Chest Pain',
      icon: PhosphorIconsDuotone.heart,
      color: AppColors.danger,
      steps: [
        'Call emergency services (112) immediately',
        'Have the person sit or lie down',
        'Loosen tight clothing',
        'Give aspirin if not allergic and person is conscious',
      ],
    ),
    (
      title: 'Choking',
      icon: PhosphorIconsDuotone.warning,
      color: AppColors.amber,
      steps: [
        'Ask "Are you choking?"',
        'If unable to speak, perform Heimlich',
        'Lean person forward, give 5 back blows',
        'Give 5 abdominal thrusts if needed',
      ],
    ),
    (
      title: 'Severe Bleeding',
      icon: PhosphorIconsDuotone.firstAid,
      color: AppColors.teal,
      steps: [
        'Apply firm pressure with clean cloth',
        'Do not remove cloth — add more if needed',
        'Elevate the injured area above heart',
        'Call emergency services (112) for deep or arterial wounds',
      ],
    ),
  ];

  static Future<void> _dial(String number) async {
    final uri = Uri.parse('tel:${number.replaceAll(RegExp(r'[^0-9+]'), '')}');
    try {
      await launchUrl(uri);
    } catch (_) {
      AppMessenger.error('Unable to start the call');
    }
  }

  /// Web shows a confirm modal before dialing — false calls delay real help.
  Future<void> _confirmCall(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Call ${AppConfig.emergencyNumber}?'),
        content: const Text(
          'You are about to call emergency services. Only continue if this is a real '
          'emergency — false calls can delay help to people in real need.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Call Now', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _dial(AppConfig.emergencyNumber);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Text('Emergency',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 4),
          Text(
            'Quick access to emergency services and first aid guidance',
            style: TextStyle(fontSize: 13.5, color: t.ink2),
          ),
          const SizedBox(height: 20),

          // ── Hero call button ──
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsDuotone.ambulance, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Need immediate help?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap below to call emergency services',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _confirmCall(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsFill.phone, size: 19, color: Color(0xFFDC2626)),
                        SizedBox(width: 9),
                        Text(
                          'Call 911',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Emergency numbers ──
          Text('Emergency Numbers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 12),
          for (final c in _contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _dial(c.number),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(c.icon, size: 20, color: c.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.label,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                            const SizedBox(height: 2),
                            Text(c.number, style: TextStyle(fontSize: 12.5, color: t.ink3)),
                          ],
                        ),
                      ),
                      Icon(PhosphorIconsRegular.phone, size: 17, color: t.ink3),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),

          // ── First aid quick reference ──
          Text('First Aid Quick Reference',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 12),
          for (final tip in _firstAid)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: tip.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(tip.icon, size: 18, color: tip.color),
                        ),
                        const SizedBox(width: 11),
                        Text(tip.title,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < tip.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 19,
                              height: 19,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tip.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: tip.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                tip.steps[i],
                                style: TextStyle(fontSize: 13, height: 1.4, color: t.ink2),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── Find nearest hospital ──
          GestureDetector(
            onTap: () => AppMessenger.info('Location services coming soon!'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(PhosphorIconsDuotone.mapPin, size: 20, color: AppColors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Find Nearest Hospital',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
                    ),
                  ),
                  Icon(PhosphorIconsBold.arrowRight, size: 16, color: t.ink3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
