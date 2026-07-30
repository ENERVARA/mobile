import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import 'about_content.dart';
import 'widgets/about_parts.dart';

/// The narrative half of About — the site's `/about` page: what Enervara is,
/// the vision behind it, and the founder.
class AboutStoryPage extends StatelessWidget {
  const AboutStoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            const AboutAppBar('About Enervara'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  // ── Hero ──
                  const Eyebrow('About Enervara'),
                  const SizedBox(height: 12),
                  const SplitHeadline(
                    lead: kAboutHeadlineLead,
                    accent: kAboutHeadlineAccent,
                  ),
                  const SizedBox(height: 22),
                  for (final p in kAboutParas) ...[
                    AboutPara(p),
                    const SizedBox(height: 16),
                  ],
                  const _EmphasisCard(kAboutEmphasis),
                  const SizedBox(height: 16),
                  for (final p in kAboutParasAfter) AboutPara(p),

                  const _Divider(),

                  // ── Vision ──
                  const Eyebrow('Our vision'),
                  const SizedBox(height: 12),
                  Text(
                    kVisionHeadline,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.32,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AboutPara(kVisionBody),
                  const SizedBox(height: 22),
                  const PullQuote(
                    lead: kVisionQuoteLead,
                    accent: kVisionQuoteAccent,
                  ),

                  const _Divider(),

                  // ── Founder ──
                  const Eyebrow('Meet the founder'),
                  const SizedBox(height: 14),
                  const _FounderCard(),
                  const SizedBox(height: 18),
                  Text(
                    kFounderTagline,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppColors.tealD,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < kFounderParas.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    AboutPara(kFounderParas[i]),
                  ],
                  const SizedBox(height: 22),
                  const PullQuote(
                    lead: kFounderQuoteLead,
                    accent: kFounderQuoteAccent,
                    inline: true,
                  ),

                  const SizedBox(height: 34),
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

/// The one line the site sets in full-strength ink between the two hero
/// paragraphs — given a soft teal card here so it holds the same weight.
class _EmphasisCard extends StatelessWidget {
  final String text;
  const _EmphasisCard(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: t.ink,
        ),
      ),
    );
  }
}

/// Portrait + name plate. Falls back to a gradient monogram until
/// [kFounderPhoto] is added to the bundle.
class _FounderCard extends StatelessWidget {
  const _FounderCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              kFounderPhoto,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _Monogram(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kFounderName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        kFounderRole,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    final initials = kFounderName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.teal, AppColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Divider(height: 1, color: context.tokens.line),
      );
}
