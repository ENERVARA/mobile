import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';

/// Standard page title block (redesign) — title + subtitle with optional action.
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
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: t.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(fontSize: 14, color: t.ink2)),
      ],
    );

    if (action == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 20), child: titleBlock);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: titleBlock), const SizedBox(width: 16), action!],
      ),
    );
  }
}
