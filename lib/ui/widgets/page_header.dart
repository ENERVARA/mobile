import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';

/// Standard page title block (redesign). Ported from `PageHeader.tsx`:
/// `text-[1.8rem] font-bold tracking-[-.03em]` title, `0.92rem` subtitle, and an
/// optional trailing action that wraps beneath the title on narrow screens.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const PageHeader({super.key, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28.8,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.864,
            height: 1.25,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(fontSize: 14.72, height: 1.5, color: t.ink2)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: action == null
          ? SizedBox(width: double.infinity, child: titleBlock)
          // flex-wrap + justify-between + gap-[18px]: the action drops below
          // the title when the two don't fit on one line.
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 18,
              runSpacing: 18,
              children: [titleBlock, action!],
            ),
    );
  }
}
