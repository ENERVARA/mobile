import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../data/constants/symptoms.dart';
import '../../../../data/models/speciality.dart';
import '../../../widgets/common.dart';
import '../../../widgets/speciality_icon.dart';

enum _View { root, symptoms, results }

/// The specialist-picker content shared by Start new care's modal and the
/// speciality-picker modal — a direct speciality list alongside a "pick by
/// symptom" path. Ported from `SpecialistFinder.tsx`; both entry points render
/// this inside their own modal, passing only their own header copy and pick
/// handler.
class SpecialistFinder extends StatefulWidget {
  final String rootTitle;
  final String rootSubtitle;

  /// Called with the chosen speciality's slug — same contract regardless of
  /// whether it was picked directly or reached via a symptom.
  final ValueChanged<String> onPick;

  const SpecialistFinder({
    super.key,
    required this.rootTitle,
    required this.rootSubtitle,
    required this.onPick,
  });

  @override
  State<SpecialistFinder> createState() => _SpecialistFinderState();
}

class _SpecialistFinderState extends State<SpecialistFinder> {
  _View _view = _View.root;
  Symptom? _symptom;

  List<Speciality> get _specialists =>
      kSpecialities.where((s) => isSpecialityEnabled(s.slug)).toList();

  void _openSymptom(Symptom s) => setState(() {
        _symptom = s;
        _view = _View.results;
      });

  @override
  Widget build(BuildContext context) {
    // One shared slide: each view enters from the right and exits to the left,
    // so picking a symptom reads as drilling in, and Back reads as backing out.
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, anim) {
          final isIncoming = child.key == ValueKey(_view);
          final offset = Tween<Offset>(
            begin: Offset(isIncoming ? 28 / 300 : -28 / 300, 0),
            end: Offset.zero,
          ).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: offset, child: child),
          );
        },
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: KeyedSubtree(key: ValueKey(_view), child: _buildView(context)),
      ),
    );
  }

  Widget _buildView(BuildContext context) {
    switch (_view) {
      case _View.root:
        return _buildRoot(context);
      case _View.symptoms:
        return _buildSymptoms(context);
      case _View.results:
        return _buildResults(context);
    }
  }

  Widget _buildRoot(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 40, bottom: 8),
          child: Text(
            widget.rootTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: dark ? const Color(0xFFF4F4F5) : const Color(0xFF111827),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            widget.rootSubtitle,
            style: TextStyle(fontSize: 14, height: 1.43, color: t.ink2),
          ),
        ),
        const SizedBox(height: 10),
        for (final spec in _specialists) ...[
          _SpecialityRow(spec: spec, onTap: () => widget.onPick(spec.slug)),
          const SizedBox(height: 10),
        ],
        // Thin divider — a horizontal rule when stacked on mobile.
        const SizedBox(height: 10),
        Container(height: 1, color: t.line),
        const SizedBox(height: 20),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _view = _View.symptoms),
          child: DashedBox(
            radius: 16,
            width: double.infinity,
            color: AppColors.teal.withValues(alpha: 0.05),
            borderColor: AppColors.teal.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.tealCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(PhosphorIconsBold.magnifyingGlass, size: 22.4, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Not sure? Pick a symptom',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose based on how you feel, we’ll match you to the right care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.48, height: 1.375, color: t.ink3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSymptoms(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewHeader(
          onBack: () => setState(() => _view = _View.root),
          title: "What's bothering you?",
          subtitle: "Pick the symptom closest to what you're feeling.",
        ),
        LayoutBuilder(
          builder: (context, c) {
            // grid-cols-4 gap-4 horizontally; rows get extra vertical gap
            // since each cell now carries a label under the icon.
            const gap = 16.0;
            final w = (c.maxWidth - gap * 3) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap + 8,
              children: [
                for (final s in kSymptoms)
                  SizedBox(
                    width: w,
                    child: _SymptomButton(symptom: s, onTap: () => _openSymptom(s)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final symptom = _symptom!;
    final matched = _specialists.where((s) => symptom.specialitySlugs.contains(s.slug)).toList();
    final primary = specialityBySlug(symptom.specialitySlugs.first);
    final iconColor = primary != null ? AppColors.hex(primary.color) : AppColors.teal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewHeader(
          onBack: () => setState(() => _view = _View.symptoms),
          title: 'Best for ${symptom.label}',
          subtitle: "These specialists can help with what you're experiencing.",
          icon: symptom.icon,
          iconColor: iconColor,
        ),
        for (final spec in matched) ...[
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: _ResultCard(spec: spec, onTap: () => widget.onPick(spec.slug)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SpecialityRow extends StatelessWidget {
  final Speciality spec;
  final VoidCallback onTap;
  const _SpecialityRow({required this.spec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.hex(spec.color),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: SpecialityIcon(icon: spec.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.name,
                      style: TextStyle(
                        fontSize: 14.4,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        spec.shortDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.16, height: 1.375, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomButton extends StatelessWidget {
  final Symptom symptom;
  final VoidCallback onTap;
  const _SymptomButton({required this.symptom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final primary = specialityBySlug(symptom.specialitySlugs.first);
    final color = primary != null ? AppColors.hex(primary.color) : AppColors.teal;
    // The web shows the label as a hover tooltip; touch has no hover, so the
    // label is printed under the icon instead of hiding behind a long-press.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          label: symptom.label,
          button: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0x1f / 255),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(symptom.icon, size: 21.6, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                symptom.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.88, fontWeight: FontWeight.w600, height: 1.2, color: t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color? iconColor;
  const _ViewHeader({
    required this.onBack,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 36, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(PhosphorIconsBold.arrowLeft, size: 16, color: t.ink2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.teal).withValues(alpha: 0x1f / 255),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15.2, color: iconColor ?? AppColors.teal),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.8,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: dark ? const Color(0xFFF4F4F5) : t.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink3),
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

class _ResultCard extends StatelessWidget {
  final Speciality spec;
  final VoidCallback onTap;
  const _ResultCard({required this.spec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.hex(spec.color),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SpecialityIcon(icon: spec.icon, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        spec.shortDescription,
                        style: TextStyle(fontSize: 12.8, height: 1.375, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(PhosphorIconsBold.arrowRight, size: 17.6, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
