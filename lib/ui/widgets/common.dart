import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/accent.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Small building blocks shared by the redesigned screens. Each mirrors a
// recurring Tailwind pattern in the web app so screens read like their React
// counterparts.
// ─────────────────────────────────────────────────────────────────────────────

/// The in-shell page scroller: `px-4`, `pt-[18px]` under the header and a bottom
/// pad that clears the fixed tab bar (`pb-[calc(80px+safe)]`).
class ShellPage extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;
  const ShellPage({super.key, required this.children, this.controller, this.padding});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      controller: controller,
      padding: padding ?? EdgeInsets.fromLTRB(16, 18, 16, 80 + safeBottom),
      children: children,
    );
  }
}

/// `border-dashed` container (Flutter has no dashed border): a rounded rect
/// whose 1px outline is drawn as 3px dashes with 3px gaps.
class DashedBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double? width;

  const DashedBox({
    super.key,
    required this.child,
    this.radius = 14,
    this.color,
    this.borderColor,
    this.padding = EdgeInsets.zero,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CustomPaint(
      foregroundPainter: _DashedPainter(color: borderColor ?? t.line, radius: radius),
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.5);
    final path = Path()..addRRect(rrect);
    const dash = 3.0, gap = 3.0;
    for (final PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color || old.radius != radius;
}

/// `h2.mb-2.5.text-[0.76rem].font-bold.uppercase.tracking-[0.1em].text-ink-3`
class SectionLabel extends StatelessWidget {
  final String text;
  final double bottom;
  final EdgeInsetsGeometry padding;
  const SectionLabel(
    this.text, {
    super.key,
    this.bottom = 10,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom).add(padding),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12.16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.216,
          height: 1.5,
          color: context.tokens.ink3,
        ),
      ),
    );
  }
}

/// Soft-tinted rounded-square icon (`grid size-10 place-items-center rounded-[11px]`
/// with `ACCENT_STYLE`).
class AccentIconBox extends StatelessWidget {
  final IconData icon;
  final Accent accent;
  final double size;
  final double radius;
  final double iconSize;

  const AccentIconBox({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
    this.radius = 11,
    this.iconSize = 17.6,
  });

  @override
  Widget build(BuildContext context) {
    final s = accent.style;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: s.background, borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: iconSize, color: s.color),
    );
  }
}

/// A small status pill tinted by [Accent] (`rounded-full px-2 py-0.5 text-[0.7rem] font-semibold`).
class AccentPill extends StatelessWidget {
  final String label;
  final Accent accent;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final IconData? icon;
  final double iconSize;

  const AccentPill({
    super.key,
    required this.label,
    required this.accent,
    this.fontSize = 11.2,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    this.icon,
    this.iconSize = 13.6,
  });

  @override
  Widget build(BuildContext context) {
    final s = accent.style;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: s.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: s.color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: s.color),
          ),
        ],
      ),
    );
  }
}

/// Filter chip row item — `rounded-full px-3.5 py-[7px] text-[0.82rem] font-semibold`.
class RoundedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const RoundedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 13.12,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.teal.withValues(alpha: dark ? 0.18 : 0.12)
              : t.card,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: t.line),
        ),
        // A 1px border on the unselected chip makes it 2px taller than the
        // selected one in CSS too (no border on the active chip); keep parity.
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: selected ? (dark ? AppColors.teal : AppColors.tealD) : t.ink2,
          ),
        ),
      ),
    );
  }
}

/// Icon + text search input. Two web variants share this: the pill-ish
/// `h-10 rounded-[14px] border-[1.5px]` field (Specialities, Lab results) and the
/// `rounded-[12px] border` field (Records).
class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double radius;
  final double borderWidth;
  final double? height;
  final double hPad;
  final double vPad;
  final double fontSize;
  final bool clearable;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.radius = 14,
    this.borderWidth = 1.5,
    this.height = 40,
    this.hPad = 16,
    this.vPad = 0,
    this.fontSize = 14.08,
    this.clearable = false,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _focused ? AppColors.teal : t.line,
          width: widget.borderWidth,
        ),
        boxShadow: _focused && widget.borderWidth > 1
            ? [BoxShadow(color: AppColors.teal.withValues(alpha: 0.12), spreadRadius: 3)]
            : null,
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.magnifyingGlass, size: 16.8, color: t.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _c,
              focusNode: _focus,
              onChanged: (v) {
                widget.onChanged(v);
                if (widget.clearable) setState(() {});
              },
              style: TextStyle(fontSize: widget.fontSize, color: t.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: widget.fontSize, color: t.ink3),
              ),
            ),
          ),
          if (widget.clearable && _c.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _c.clear();
                widget.onChanged('');
                setState(() {});
              },
              child: Icon(PhosphorIconsRegular.x, size: 16, color: t.ink3),
            ),
        ],
      ),
    );
  }
}

enum WebButtonVariant { primary, outline, ghost, soft, dangerOutline, white }

/// The web's rounded CTA buttons (`rounded-[11px] px-5 py-2.5 text-[0.9rem]
/// font-semibold`) in their recurring variants.
class WebButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final WebButtonVariant variant;
  final bool loading;
  final bool expand;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double radius;
  final double iconSize;
  final bool shadow;

  const WebButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.variant = WebButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.fontSize = 14.4,
    this.radius = 11,
    this.iconSize = 16,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    Color? bg;
    Color fg;
    BoxBorder? border;
    switch (variant) {
      case WebButtonVariant.primary:
        bg = AppColors.teal;
        fg = Colors.white;
        break;
      case WebButtonVariant.outline:
        bg = t.card;
        fg = t.ink;
        border = Border.all(color: t.line);
        break;
      case WebButtonVariant.ghost:
        bg = null;
        fg = t.ink2;
        border = Border.all(color: t.line);
        break;
      case WebButtonVariant.soft:
        bg = t.soft;
        fg = dark ? AppColors.teal : AppColors.tealD;
        break;
      case WebButtonVariant.dangerOutline:
        bg = null;
        fg = AppColors.coral;
        border = Border.all(color: t.line);
        break;
      case WebButtonVariant.white:
        bg = Colors.white;
        fg = AppColors.tealD;
        break;
    }
    final disabled = onTap == null || loading;
    return Opacity(
      opacity: onTap == null && !loading ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: disabled ? null : onTap,
          child: Ink(
            width: expand ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: border,
              boxShadow: shadow
                  ? [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.6),
                        blurRadius: 18,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else if (icon != null)
                  Icon(icon, size: iconSize, color: fg),
                if (loading || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum LegacyButtonVariant { primary, secondary, ghost, danger }

enum LegacyButtonSize { sm, md, lg }

/// The original `Button` primitive (`components/ui/Button.tsx`) — still used by
/// the booking / prescription / profile screens: `rounded-[12px]`, sizes
/// sm (h-9 px-4 text-sm), md (h-11 px-5 text-sm), lg (h-12 px-6 text-base);
/// `primary` is the filled brand colour, `secondary` a 1.5px brand outline,
/// `danger` a 1.5px red outline.
class LegacyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final LegacyButtonVariant variant;
  final LegacyButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;

  const LegacyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LegacyButtonVariant.primary,
    this.size = LegacyButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    // `--color-primary` flips to a brighter teal in dark mode.
    final primary = dark ? const Color(0xFF2EDBC9) : const Color(0xFF0BB5A6);
    const danger = Color(0xFFEF4444);
    final height = switch (size) {
      LegacyButtonSize.sm => 36.0,
      LegacyButtonSize.md => 44.0,
      LegacyButtonSize.lg => 48.0,
    };
    final hPad = switch (size) {
      LegacyButtonSize.sm => 16.0,
      LegacyButtonSize.md => 20.0,
      LegacyButtonSize.lg => 24.0,
    };
    final fontSize = size == LegacyButtonSize.lg ? 16.0 : 14.0;
    final gap = size == LegacyButtonSize.sm ? 6.0 : 8.0;

    Color? bg;
    Color fg;
    BoxBorder? border;
    FontWeight weight = FontWeight.w600;
    switch (variant) {
      case LegacyButtonVariant.primary:
        bg = primary;
        fg = Colors.white;
        break;
      case LegacyButtonVariant.secondary:
        fg = primary;
        border = Border.all(color: primary, width: 1.5);
        break;
      case LegacyButtonVariant.ghost:
        fg = const Color(0xFF6B7280);
        weight = FontWeight.w500;
        if (dark) fg = const Color(0xFFA1A1AA);
        break;
      case LegacyButtonVariant.danger:
        fg = danger;
        border = Border.all(color: danger, width: 1.5);
        break;
    }
    final disabled = onPressed == null || isLoading;
    return Opacity(
      opacity: onPressed == null && !isLoading ? 0.5 : 1,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : onPressed,
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: border,
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  else ...[
                    if (icon != null) ...[
                      Icon(icon, size: fontSize + 2, color: fg),
                      SizedBox(width: gap),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: weight,
                          height: 1.4,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The legacy `Card` primitive — `rounded-[16px]`, the surface colour and a
/// soft `shadow-md`; padding md = 24 by default.
class LegacyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const LegacyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

/// The web's compact `<select>` (`h-10 rounded-[11px] border-[1.5px] border-line
/// bg-card px-3 text-[0.88rem]`), as a themed dropdown.
class WebSelect<T> extends StatelessWidget {
  final T? value;
  final List<({T value, String label})> options;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final double height;
  final double radius;
  final double fontSize;
  final double borderWidth;
  final FontWeight fontWeight;
  final Color? textColor;

  const WebSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.height = 40,
    this.radius = 11,
    this.fontSize = 14.08,
    this.borderWidth = 1.5,
    this.fontWeight = FontWeight.w400,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final safe = options.any((o) => o.value == value) ? value : null;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.line, width: borderWidth),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safe,
          isExpanded: true,
          isDense: true,
          dropdownColor: t.card,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(PhosphorIconsRegular.caretDown, size: 14, color: t.ink3),
          hint: hint == null
              ? null
              : Text(hint!, style: TextStyle(fontSize: fontSize, color: t.ink3)),
          style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: textColor ?? t.ink),
          onChanged: onChanged,
          items: [
            for (final o in options)
              DropdownMenuItem<T>(
                value: o.value,
                child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

/// Native-style confirmation for destructive actions (the web uses
/// `window.confirm`). Resolves true when the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String message,
  String confirmLabel = 'Delete',
  String? title,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: AppColors.coral)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Centred empty / error block inside a dashed container
/// (`rounded-[…] border border-dashed border-line px-… py-… text-center`).
class DashedEmpty extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? body;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double titleSize;
  final double bodySize;
  final Widget? action;
  final Color? color;
  final double? bodyMaxWidth;

  const DashedEmpty({
    super.key,
    this.icon,
    required this.title,
    this.body,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
    this.iconSize = 24,
    this.titleSize = 14.4,
    this.bodySize = 12.8,
    this.action,
    this.color,
    this.bodyMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DashedBox(
      radius: radius,
      color: color,
      padding: padding,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: iconSize, color: t.ink3),
          if (icon != null) const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600, color: t.ink),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bodyMaxWidth ?? double.infinity),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: bodySize, height: 1.5, color: t.ink3),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Square rounded back button used by sub-pages (`grid size-9 rounded-[11px]
/// border border-line bg-card text-ink-2`).
class BackSquareButton extends StatelessWidget {
  final VoidCallback onTap;
  final String semanticLabel;
  const BackSquareButton({super.key, required this.onTap, this.semanticLabel = 'Back'});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.line),
          ),
          alignment: Alignment.center,
          child: Icon(PhosphorIconsRegular.arrowLeft, size: 16, color: t.ink2),
        ),
      ),
    );
  }
}
