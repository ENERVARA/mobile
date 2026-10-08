import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/css_shadow.dart';
import '../../../../data/models/chat.dart';
import 'question_block.dart';

/// Dispatches a single structured block to its renderer — mirrors
/// `blocks/BlockRenderer.tsx`. Never throws: an unrecognised block falls back
/// to plain text (if any) or renders nothing.
class BlockRenderer extends StatelessWidget {
  final MessageBlock block;
  const BlockRenderer({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final b = block;
    if (b is SummaryBlock) return _summaryBubble(context, b.text);
    if (b is ConditionListBlock) {
      return _ConditionCards(conditions: b.conditions);
    }
    if (b is WarningBlock) {
      return _WarningBanner(text: b.text, severity: b.severity);
    }
    if (b is NextStepsBlock) return _NextSteps(steps: b.steps);
    if (b is BulletListBlock) {
      return _BulletList(title: b.title, items: b.items);
    }
    if (b is KeyPointsBlock) return _KeyPoints(points: b.points);
    if (b is DecisionBlock) {
      return _DecisionBanner(verdict: b.verdict, rationale: b.rationale);
    }
    if (b is OtcMedicationsBlock) return _OtcMedications(meds: b.medications);
    if (b is LabTestsBlock) return _LabTests(tests: b.tests);
    if (b is QuestionBlock) return QuestionBlockView(block: b);
    if (b is FollowUpQuestionsBlock) return const SizedBox.shrink();
    if (b is UnknownBlock) {
      final t = b.text;
      if (t != null && t.trim().isNotEmpty) return _summaryBubble(context, t);
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }
}

const _novaRadius = BorderRadius.only(
  topLeft: Radius.circular(4),
  topRight: Radius.circular(16),
  bottomRight: Radius.circular(16),
  bottomLeft: Radius.circular(16),
);

/// Nova's reply bubble (`.nova-bubble`): the card surface with a teal hairline,
/// a soft teal glow and a small particle cluster breaking its outer corner.
/// Used for plain replies, streamed text and the "thinking" state.
class NovaBubble extends StatelessWidget {
  final Widget child;
  const NovaBubble({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: _novaRadius,
            border: Border.all(color: AppColors.teal.withValues(alpha: context.isDark ? 0.24 : 0.18)),
            boxShadow: [
              cssShadow(const Color(0x081A2027), y: 1, blur: 2),
              cssShadow(AppColors.teal.withValues(alpha: 0.35), y: 6, blur: 16, spread: -8),
            ],
          ),
          child: child,
        ),
        const Positioned(
          top: -6,
          right: -8,
          width: 28,
          height: 22,
          child: IgnorePointer(child: CustomPaint(painter: _ParticlePainter())),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    void dot(double x, double y, double r, Color c) {
      final center = Offset(x, y);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)], stops: const [0, 0.7])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    dot(21, 6, 2.6, AppColors.teal.withValues(alpha: 0.55));
    dot(12, 13, 1.9, AppColors.cyan.withValues(alpha: 0.45));
    dot(24, 15, 1.3, AppColors.teal.withValues(alpha: 0.32));
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => false;
}

/// Plain Nova text in the teal-hairline bubble (`NOVA_BUBBLE` in MessageList.tsx).
Widget novaTextBubble(BuildContext context, String text) => NovaBubble(
      child: NovaRichText(
        text: text,
        style: TextStyle(fontSize: 13.76, height: 1.5, color: context.tokens.ink),
      ),
    );

/// A `summary` block / default text block: `rounded-[4px_16px_16px_16px] bg-soft`.
Widget _summaryBubble(BuildContext context, String text) {
  final t = context.tokens;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(color: t.soft, borderRadius: _novaRadius),
    child: NovaRichText(
      text: text,
      style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink),
    ),
  );
}

// ─── Shared card scaffolding ───────────────────────────────────────────────

/// The card shell used by every structured list block (condition list, next
/// steps, OTC meds, lab tests, bullet list, key points). Mirrors the
/// dashboard's block cards 1:1 — header (icon + label) always static, body
/// always fully rendered. No collapse/expand: the dashboard's block
/// components (`NextStepsList.tsx`, `OtcMedications.tsx`, `LabTests.tsx`,
/// `ConditionCards.tsx`, `BulletList.tsx`, `KeyPoints.tsx`) never hide their
/// content behind a toggle, so this must not either — a collapsed-by-default
/// card previously made every non-trivial reply (anything beyond a plain
/// `summary` block) look empty until the user discovered they had to tap it.
class _BlockCard extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Widget body;

  const _BlockCard({this.icon, this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    Widget? header;
    if (hasLabel) {
      header = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: t.soft,
          border: Border(bottom: BorderSide(color: t.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? PhosphorIconsBold.info,
                size: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: t.ink2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (header != null) header, body],
      ),
    );
  }
}

// ─── condition_list ──────────────────────────────────────────────────────────

class _ConditionCards extends StatelessWidget {
  final List<ConditionEntry> conditions;
  const _ConditionCards({required this.conditions});

  /// high → coral, moderate/med → amber, else → teal-d.
  ({Color bg, Color fg}) _style(String value) {
    final v = value.toLowerCase();
    if (v.contains('high')) {
      return (bg: AppColors.coral.withValues(alpha: 0.12), fg: AppColors.coral);
    }
    if (v.contains('mod') || v.contains('med')) {
      return (bg: AppColors.amber.withValues(alpha: 0.15), fg: AppColors.amber);
    }
    return (bg: AppColors.teal.withValues(alpha: 0.12), fg: AppColors.tealD);
  }

  @override
  Widget build(BuildContext context) {
    if (conditions.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return _BlockCard(
      icon: PhosphorIconsBold.stethoscope,
      label: 'Possible conditions',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < conditions.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      conditions[i].name,
                      style: TextStyle(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ),
                  if (conditions[i].likelihood != null &&
                      conditions[i].likelihood!.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _pill(
                      conditions[i].likelihood!,
                      _style(conditions[i].likelihood!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, ({Color bg, Color fg}) s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: s.fg,
        ),
      ),
    );
  }
}

// ─── warning ─────────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  final String? text;
  final String? severity;
  const _WarningBanner({this.text, this.severity});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = (text != null && text!.trim().isNotEmpty)
        ? text!
        : 'Please review this carefully.';
    final critical = severity == 'critical';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: critical ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: critical
              ? AppColors.coral
              : AppColors.coral.withValues(alpha: 0.3),
          width: critical ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsFill.warning,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  critical ? 'URGENT' : 'IMPORTANT',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(height: 2),
                NovaRichText(
                  text: body,
                  linkifyPhone: critical,
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: t.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── next_steps ──────────────────────────────────────────────────────────────

class _NextSteps extends StatelessWidget {
  final List<String> steps;
  const _NextSteps({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return _BlockCard(
      icon: PhosphorIconsBold.listChecks,
      label: 'Next steps',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealD,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NovaRichText(
                      text: steps[i],
                      linkifyPhone: true,
                      style: TextStyle(
                        fontSize: 13.6,
                        height: 1.35,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── bullet_list ─────────────────────────────────────────────────────────────

class _BulletList extends StatelessWidget {
  final String? title;
  final List<String> items;
  const _BulletList({this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final hasTitle = title != null && title!.trim().isNotEmpty;
    return _BlockCard(
      icon: PhosphorIconsBold.listBullets,
      label: hasTitle ? title!.trim() : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: NovaRichText(
                      text: items[i],
                      style: TextStyle(
                        fontSize: 13.6,
                        height: 1.35,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── key_points ──────────────────────────────────────────────────────────────

class _KeyPoints extends StatelessWidget {
  final List<String> points;
  const _KeyPoints({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return _BlockCard(
      icon: PhosphorIconsBold.lightbulb,
      label: 'Key points',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < points.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      PhosphorIconsFill.checkCircle,
                      size: 16,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: NovaRichText(
                      text: points[i],
                      style: TextStyle(
                        fontSize: 13.6,
                        height: 1.35,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── decision ────────────────────────────────────────────────────────────────

const Map<String, String> _verdictLabel = {
  'yes': 'YES',
  'no': 'NO',
  'possibly': 'POSSIBLY',
  'seek_urgent_care': 'SEEK URGENT CARE',
  'insufficient_information': 'NEED MORE INFO',
};

class _DecisionBanner extends StatelessWidget {
  final String verdict;
  final String rationale;
  const _DecisionBanner({required this.verdict, required this.rationale});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = _verdictLabel[verdict] ?? 'NEED MORE INFO';
    final emergency = verdict == 'seek_urgent_care';

    late final Color badgeBg;
    late final IconData icon;
    late final Color cardBorder;
    late final Color cardBg;
    switch (verdict) {
      case 'yes':
        badgeBg = AppColors.teal;
        icon = PhosphorIconsFill.checkCircle;
        cardBorder = AppColors.teal.withValues(alpha: 0.35);
        cardBg = AppColors.teal.withValues(alpha: 0.07);
        break;
      case 'no':
        badgeBg = AppColors.coral;
        icon = PhosphorIconsFill.xCircle;
        cardBorder = AppColors.coral.withValues(alpha: 0.35);
        cardBg = AppColors.coral.withValues(alpha: 0.07);
        break;
      case 'possibly':
        badgeBg = AppColors.amber;
        icon = PhosphorIconsFill.scales;
        cardBorder = AppColors.amber.withValues(alpha: 0.4);
        cardBg = AppColors.amber.withValues(alpha: 0.09);
        break;
      case 'seek_urgent_care':
        badgeBg = AppColors.coral;
        icon = PhosphorIconsFill.firstAid;
        cardBorder = AppColors.coral;
        cardBg = AppColors.coral.withValues(alpha: 0.1);
        break;
      default:
        badgeBg = t.ink3;
        icon = PhosphorIconsFill.info;
        cardBorder = t.line;
        cardBg = t.soft;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: emergency ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emergency)
            Container(
              width: double.infinity,
              color: AppColors.coral,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(
                left: 14,
                right: 14,
                top: 13,
                bottom: 4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: emergency ? 12 : 8,
              bottom: emergency ? 12 : 13,
            ),
            child: NovaRichText(
              text: rationale,
              style: TextStyle(fontSize: 13.8, height: 1.4, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── otc_medications ─────────────────────────────────────────────────────────

class _OtcMedications extends StatelessWidget {
  final List<OtcMedication> meds;
  const _OtcMedications({required this.meds});

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return _BlockCard(
      icon: PhosphorIconsBold.pill,
      label: 'Over-the-counter options',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < meds.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        meds[i].name,
                        style: TextStyle(
                          fontSize: 14.4,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      if (meds[i].dosage != null &&
                          meds[i].dosage!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            meds[i].dosage!,
                            style: const TextStyle(
                              fontSize: 10.9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.tealD,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meds[i].purpose,
                    style: TextStyle(
                      fontSize: 13.1,
                      height: 1.35,
                      color: t.ink2,
                    ),
                  ),
                  if (meds[i].caution != null &&
                      meds[i].caution!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              PhosphorIconsFill.warningCircle,
                              size: 14,
                              color: AppColors.amber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              meds[i].caution!,
                              style: TextStyle(
                                fontSize: 12.3,
                                height: 1.35,
                                color: AppColors.hex('#8A6A10'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.line)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              'Self-care suggestions, not a prescription — check with a pharmacist.',
              style: TextStyle(
                fontSize: 10.9,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: t.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── lab_tests ───────────────────────────────────────────────────────────────

const Map<String, String> _urgencyLabel = {
  'routine': 'Routine',
  'soon': 'Soon',
  'urgent': 'Urgent',
};

class _LabTests extends StatelessWidget {
  final List<LabTest> tests;
  const _LabTests({required this.tests});

  ({Color bg, Color fg}) _urgencyStyle(BuildContext context, String? urgency) {
    switch (urgency) {
      case 'urgent':
        return (
          bg: AppColors.coral.withValues(alpha: 0.14),
          fg: AppColors.coral,
        );
      case 'soon':
        return (
          bg: AppColors.amber.withValues(alpha: 0.16),
          fg: AppColors.hex('#8A6A10'),
        );
      default:
        return (bg: context.tokens.soft, fg: context.tokens.ink3);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return _BlockCard(
      icon: PhosphorIconsBold.flask,
      label: 'Recommended tests',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tests.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        tests[i].name,
                        style: TextStyle(
                          fontSize: 14.4,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      if (tests[i].urgency != null &&
                          tests[i].urgency!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _urgencyStyle(context, tests[i].urgency).bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _urgencyLabel[tests[i].urgency] ??
                                tests[i].urgency!,
                            style: TextStyle(
                              fontSize: 10.9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _urgencyStyle(
                                context,
                                tests[i].urgency,
                              ).fg,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tests[i].reason,
                    style: TextStyle(
                      fontSize: 13.1,
                      height: 1.35,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.line)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              'Suggested investigations to discuss with your doctor — not a lab order.',
              style: TextStyle(
                fontSize: 10.9,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: t.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RichText (bold/italic/code + bullets + phone links) ─────────────────────

/// Lightweight markdown for Nova's block text — ported from `RichText.tsx`.
/// Handles **bold**, *italic*, `code`, markdown list markers and (opt-in)
/// tappable `tel:` phone links.
class NovaRichText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool linkifyPhone;
  const NovaRichText({
    super.key,
    required this.text,
    required this.style,
    this.linkifyPhone = false,
  });

  @override
  State<NovaRichText> createState() => _NovaRichTextState();
}

class _NovaRichTextState extends State<NovaRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final _inlineRe = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
  static final _phoneRe = RegExp(
    r'(\b(?:911|999|112|108|102|100|101|000|111|118|119|120|1-1-1|9-1-1)\b|\+?\d[\d\s().-]{6,}\d)',
  );

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final lines = widget.text.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);

      if (bullet != null) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _line(bullet.group(1)!)),
            ],
          ),
        );
      } else if (numbered != null) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${numbered.group(1)}.',
                style: widget.style.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealD,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _line(numbered.group(2)!)),
            ],
          ),
        );
      } else {
        children.add(_line(line));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _line(String text) =>
      Text.rich(TextSpan(style: widget.style, children: _inline(text)));

  List<InlineSpan> _inline(String text) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(text)) {
      if (m.start > last) _plain(text.substring(last, m.start), spans);
      final tok = m.group(0)!;
      if (tok.startsWith('**')) {
        spans.add(
          TextSpan(
            text: tok.substring(2, tok.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (tok.startsWith('*')) {
        spans.add(
          TextSpan(
            text: tok.substring(1, tok.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: tok.substring(1, tok.length - 1),
            style: TextStyle(
              color: AppColors.tealD,
              backgroundColor: AppColors.teal.withValues(alpha: 0.1),
              fontFamily: 'monospace',
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) _plain(text.substring(last), spans);
    return spans;
  }

  void _plain(String text, List<InlineSpan> spans) {
    if (text.isEmpty) return;
    if (!widget.linkifyPhone) {
      spans.add(TextSpan(text: text));
      return;
    }
    var last = 0;
    for (final m in _phoneRe.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final seg = m.group(0)!;
      final tel = seg.replaceAll(RegExp(r'[^\d+]'), '');
      final rec = TapGestureRecognizer()
        ..onTap = () => launchUrl(Uri.parse('tel:$tel'));
      _recognizers.add(rec);
      spans.add(
        TextSpan(
          text: seg,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.tealD,
            decoration: TextDecoration.underline,
          ),
          recognizer: rec,
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  }
}
