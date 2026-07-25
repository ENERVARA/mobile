import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';

/// "Coming soon" panel — ported from `src/components/shared/ComingSoon.tsx`.
/// [asOverlay] blurs the underlying content; otherwise it renders inline.
class ComingSoon extends StatelessWidget {
  final String title;
  final String description;
  final bool asOverlay;

  const ComingSoon({
    super.key,
    this.title = 'Coming soon',
    this.description =
        "We're putting the finishing touches on this. Available in the next release — thanks for being an early-access user.",
    this.asOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final panel = Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIconsDuotone.sparkle, size: 26, color: AppColors.teal),
          ),
          const SizedBox(height: 20),
          Text(
            'COMING SOON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: t.ink2),
          ),
        ],
      ),
    );

    if (!asOverlay) {
      return Container(
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: panel,
      );
    }
    return Positioned.fill(
      child: Container(
        color: t.appBg.withValues(alpha: 0.7),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: panel,
      ),
    );
  }
}
