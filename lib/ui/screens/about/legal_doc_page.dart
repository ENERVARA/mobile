import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import 'about_content.dart';
import 'widgets/about_parts.dart';

/// Renders a [LegalDoc] — Privacy Policy, Terms of Service or Security — as one
/// card per numbered section, so a long document stays scannable on a phone.
class LegalDocPage extends StatelessWidget {
  final LegalDoc doc;
  const LegalDocPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            AboutAppBar(doc.title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                children: [
                  const Eyebrow('Legal'),
                  const SizedBox(height: 10),
                  Text(
                    doc.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(doc.version, style: TextStyle(fontSize: 12.5, color: t.ink3)),
                  const SizedBox(height: 22),
                  for (var s = 0; s < doc.sections.length; s++) ...[
                    _SectionCard(index: s + 1, section: doc.sections[s]),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
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

class _SectionCard extends StatelessWidget {
  final int index;
  final LegalSection section;
  const _SectionCard({required this.index, required this.section});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealD,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    section.heading,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var b = 0; b < section.blocks.length; b++) ...[
            if (b > 0) const SizedBox(height: 10),
            _block(section.blocks[b]),
          ],
        ],
      ),
    );
  }

  Widget _block(LegalBlock block) {
    return switch (block) {
      Para(:final text, :final strong) => AboutPara(text, strong: strong),
      Bullets(:final items) => AboutBullets(items),
      ContactLine(:final value, :final email) =>
        email ? EmailLink(value) : CompanyFootnote(value, center: false),
    };
  }
}
