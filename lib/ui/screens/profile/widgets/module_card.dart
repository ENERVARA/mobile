import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';

/// A health-profile module card: tinted icon + title on the left, an optional
/// "Add …" action on the right, then the module's own content below.
class ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const ModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor = AppColors.teal,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16.8, fontWeight: FontWeight.w600, color: t.ink),
                ),
              ),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsRegular.plus, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          actionLabel!,
                          style: const TextStyle(
                            fontSize: 13.1,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Shared empty-state block for the list modules.
class ModuleEmpty extends StatelessWidget {
  final String text;
  const ModuleEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.8, color: t.ink2),
      ),
    );
  }
}
