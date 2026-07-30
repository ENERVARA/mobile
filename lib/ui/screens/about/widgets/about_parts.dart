import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';

/// Teal dot + uppercase label — the site's section eyebrow.
class Eyebrow extends StatelessWidget {
  final String label;
  const Eyebrow(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.teal),
        ),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.tealD,
          ),
        ),
      ],
    );
  }
}

/// Two-tone display heading: [lead] in ink, [accent] in teal. Mirrors the way
/// the site colours the second half of each hero line.
class SplitHeadline extends StatelessWidget {
  final String lead;
  final String accent;
  final double fontSize;
  const SplitHeadline({
    super.key,
    required this.lead,
    required this.accent,
    this.fontSize = 27,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
      height: 1.2,
      color: t.ink,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: lead),
          TextSpan(text: accent, style: const TextStyle(color: AppColors.teal)),
        ],
      ),
    );
  }
}

/// Teal rule on the left, two lines of statement text — the site's pull quote.
class PullQuote extends StatelessWidget {
  final String lead;
  final String accent;

  /// The site sets these as two stacked lines in the vision block and as one
  /// wrapped sentence under the founder bio.
  final bool inline;

  const PullQuote({
    super.key,
    required this.lead,
    required this.accent,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const style = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, height: 1.4);
    final body = inline
        ? Text.rich(
            TextSpan(
              style: style.copyWith(color: t.ink),
              children: [
                TextSpan(text: lead),
                TextSpan(text: accent, style: const TextStyle(color: AppColors.teal)),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lead, style: style.copyWith(color: t.ink)),
              const SizedBox(height: 3),
              Text(accent, style: style.copyWith(color: AppColors.teal)),
            ],
          );

    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.teal, width: 3)),
      ),
      child: body,
    );
  }
}

/// Body paragraph at the site's reading rhythm.
class AboutPara extends StatelessWidget {
  final String text;
  final bool strong;
  const AboutPara(this.text, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: strong ? 14.6 : 14,
        height: 1.62,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: strong ? t.ink : t.ink2,
      ),
    );
  }
}

/// Teal-dot bullet list matching the legal pages on the site.
class AboutBullets extends StatelessWidget {
  final List<String> items;
  const AboutBullets(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 10),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.teal,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 13.6, height: 1.55, color: t.ink2),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tappable `mailto:` row.
class EmailLink extends StatelessWidget {
  final String address;
  const EmailLink(this.address, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openMailTo(address),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.envelopeSimple, size: 15, color: AppColors.teal),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                address,
                style: const TextStyle(
                  fontSize: 13.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hands [address] to the OS mail client, optionally prefilled.
Future<bool> openMailTo(String address, {String? subject, String? body}) async {
  final query = <String>[
    if (subject != null) 'subject=${Uri.encodeQueryComponent(subject)}',
    if (body != null) 'body=${Uri.encodeQueryComponent(body)}',
  ].join('&');
  final uri = Uri.parse('mailto:$address${query.isEmpty ? '' : '?$query'}');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) AppMessenger.error('No mail app found on this device');
    return ok;
  } catch (_) {
    AppMessenger.error('Unable to open your mail app');
    return false;
  }
}

/// Back-arrow + title bar used by the About hub and its detail pages.
class AboutAppBar extends StatelessWidget {
  final String title;
  const AboutAppBar(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: t.ink),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Company name + registered address, closing every legal page and the hub.
class CompanyFootnote extends StatelessWidget {
  final String address;

  /// Centred when closing a page; left-aligned inside a section card.
  final bool center;

  const CompanyFootnote(this.address, {super.key, this.center = true});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      address,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: 11.5, height: 1.55, color: t.ink3),
    );
  }
}
