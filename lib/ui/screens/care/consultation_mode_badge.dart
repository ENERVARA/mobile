import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';

/// How a piece of care is being handled — Nova/AI chat vs. an in-person provider
/// consultation. Ported from `ConsultationModeBadge.tsx`. The backend doesn't
/// distinguish this per-item yet (every conversation is agent-driven, every
/// appointment is offline), so callers default it; this just renders the mode.
class ConsultationModeBadge extends StatelessWidget {
  /// `agent` | `offline`
  final String mode;
  const ConsultationModeBadge({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final agent = mode == 'agent';
    final fg = agent ? (context.isDark ? AppColors.teal : AppColors.tealD) : AppColors.lav;
    final bg = agent ? AppColors.teal.withValues(alpha: 0.12) : AppColors.lav.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(agent ? PhosphorIconsFill.robot : PhosphorIconsFill.hospital, size: 12.48, color: fg),
          const SizedBox(width: 4),
          Text(
            agent ? 'Agent' : 'Offline',
            style: TextStyle(fontSize: 10.88, fontWeight: FontWeight.w600, height: 1.5, color: fg),
          ),
        ],
      ),
    );
  }
}
