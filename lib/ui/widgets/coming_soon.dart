import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/context_ext.dart';

/// "Coming soon" panel — ported from `src/components/shared/ComingSoon.tsx`.
/// [asOverlay] frosts the underlying content (a 70% tint of the page colour with
/// an 8px backdrop blur) and centres the panel on top; otherwise it renders
/// inline. As an overlay it must be a direct child of a [Stack].
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
    final dark = context.isDark;
    // Legacy `--color-*` tokens the web panel uses.
    final surface = dark ? const Color(0xFF141416) : Colors.white;
    final border = dark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E8EB);
    final primary = dark ? const Color(0xFF2EDBC9) : const Color(0xFF0BB5A6);
    final primaryLight = dark ? const Color(0x1F2EDBC9) : const Color(0xFFE6FAF7);
    final textPrimary = dark ? const Color(0xFFF4F4F5) : const Color(0xFF111827);
    final textSecondary = dark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    final bg = dark ? const Color(0xFF0A0A0B) : const Color(0xFFF8FAFB);

    final panel = Container(
      constraints: const BoxConstraints(maxWidth: 448),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: primaryLight, shape: BoxShape.circle),
            child: Icon(PhosphorIconsDuotone.sparkle, size: 26, color: primary),
          ),
          const SizedBox(height: 20),
          Text(
            'COMING SOON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.98,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.625, color: textSecondary),
          ),
        ],
      ),
    );

    if (!asOverlay) {
      return Container(
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
        child: panel,
      );
    }
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: bg.withValues(alpha: 0.7),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: panel,
          ),
        ),
      ),
    );
  }
}
