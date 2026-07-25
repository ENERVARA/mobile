import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/context_ext.dart';

enum AppButtonVariant { primary, gradient, outline, ghost, danger }

/// The app's button primitive — teal-filled by default, with gradient/outline/
/// ghost/danger variants and a loading spinner.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final IconData? icon;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = onPressed == null || loading;

    final isGradient = variant == AppButtonVariant.gradient;
    final isOutline = variant == AppButtonVariant.outline;
    final isGhost = variant == AppButtonVariant.ghost;

    Color? bgColor;
    Gradient? gradient;
    Color fg;
    BoxBorder? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = AppColors.teal;
        fg = Colors.white;
        break;
      case AppButtonVariant.gradient:
        gradient = AppGradients.hubHero;
        fg = Colors.white;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        fg = t.ink;
        border = Border.all(color: t.line);
        break;
      case AppButtonVariant.ghost:
        bgColor = t.soft;
        fg = t.ink;
        break;
      case AppButtonVariant.danger:
        bgColor = AppColors.coral;
        fg = Colors.white;
        break;
    }

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled && !loading ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: height,
            width: expand ? double.infinity : null,
            padding: expand ? null : const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: bgColor,
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: (isGradient || (!isOutline && !isGhost && variant == AppButtonVariant.primary))
                  ? [BoxShadow(color: AppColors.teal.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
