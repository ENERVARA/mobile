import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../widgets/logo.dart';
import 'about_content.dart';
import 'contact_sheet.dart';
import 'widgets/about_parts.dart';

class _Entry {
  final IconData icon;
  final String title;
  final String blurb;

  /// Route to push, or null for [onTap]-driven entries (the contact sheet).
  final String? route;
  const _Entry({
    required this.icon,
    required this.title,
    required this.blurb,
    this.route,
  });
}

const _entries = <_Entry>[
  _Entry(
    icon: PhosphorIconsRegular.info,
    title: 'About Enervara',
    blurb: 'Our mission, the vision behind the platform, and the founder.',
    route: '/about/story',
  ),
  _Entry(
    icon: PhosphorIconsRegular.shieldCheck,
    title: 'Privacy Policy',
    blurb: 'What we collect, how we use it, and the rights you hold.',
    route: '/about/privacy',
  ),
  _Entry(
    icon: PhosphorIconsRegular.fileText,
    title: 'Terms of Service',
    blurb: 'The terms you agree to when using the platform.',
    route: '/about/terms',
  ),
  _Entry(
    icon: PhosphorIconsRegular.lockKey,
    title: 'Security',
    blurb: 'Encryption, access controls, and how your data is safeguarded.',
    route: '/about/security',
  ),
  _Entry(
    icon: PhosphorIconsRegular.lifebuoy,
    title: 'Support & Contact',
    blurb: 'Questions, feedback or concerns — send us a message.',
  ),
];

/// About / legal hub, linked from a small "About" button on the Profile page.
/// Each entry opens the full page; Support opens the contact sheet.
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
            const AboutAppBar('About'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Logo(size: 44),
                        const SizedBox(height: 10),
                        Text(
                          AppConfig.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealD,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${AppConfig.version}',
                          style: TextStyle(fontSize: 12, color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  for (final e in _entries) ...[
                    _EntryCard(entry: e),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 14),
                  const CompanyFootnote(kCompanyAddress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final _Entry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final route = entry.route;
          if (route == null) {
            showContactSheet(context);
          } else {
            context.push(route);
          }
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.icon, size: 17, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.blurb,
                      style: TextStyle(fontSize: 12.6, height: 1.4, color: t.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
