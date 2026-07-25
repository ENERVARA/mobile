import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../widgets/logo.dart';

class _AboutSection {
  final IconData icon;
  final String title;
  final String body;
  const _AboutSection({required this.icon, required this.title, required this.body});
}

const _placeholder =
    "Content coming soon. We're finalising this section and will publish it here shortly.";

const _sections = <_AboutSection>[
  _AboutSection(
    icon: PhosphorIconsRegular.info,
    title: 'About Enervara',
    body: _placeholder,
  ),
  _AboutSection(
    icon: PhosphorIconsRegular.shieldCheck,
    title: 'Privacy Policy',
    body: _placeholder,
  ),
  _AboutSection(
    icon: PhosphorIconsRegular.fileText,
    title: 'Terms of Service',
    body: _placeholder,
  ),
  _AboutSection(
    icon: PhosphorIconsRegular.lifebuoy,
    title: 'Support & Contact',
    body: _placeholder,
  ),
];

/// About / legal — a placeholder page (real copy to follow) linked from a
/// small "About" button on the Profile page.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: t.ink),
                  ),
                  Text(
                    'About',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Logo(size: 44),
                        const SizedBox(height: 10),
                        Text('Enervara',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.tealD)),
                        const SizedBox(height: 2),
                        Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: t.ink3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (final s in _sections) ...[
                    _SectionCard(section: s),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _AboutSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(section.icon, size: 16, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(section.title,
                    style: TextStyle(fontSize: 14.6, fontWeight: FontWeight.w600, color: t.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(section.body, style: TextStyle(fontSize: 13, height: 1.5, color: t.ink2)),
        ],
      ),
    );
  }
}
