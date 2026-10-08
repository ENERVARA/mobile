import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';

/// Sticky "Show this to your doctor" CTA — shown above the composer once the
/// backend has flagged show_doctor_summary for the conversation, and kept
/// available for the rest of it. Tapping triggers (fresh) SOAP generation.
/// Ported from `DoctorSummaryCta.tsx`.
class DoctorSummaryCta extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const DoctorSummaryCta({
    super.key,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Pinned to the bottom of the thread itself: a soft top fade (`to_top, card 55%,
    // transparent`) keeps it from looking like it floats over the composer.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [t.card, t.card.withValues(alpha: 0)],
          stops: const [0.55, 1],
        ),
      ),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: loading ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
              boxShadow: [BoxShadow(color: const Color(0x1A0F172A), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsFill.stethoscope,
                    size: 16,
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
                        'Show this to your doctor',
                        style: TextStyle(
                          fontSize: 13.4,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        'A clinical summary of this conversation',
                        style: TextStyle(fontSize: 11.5, color: t.ink2),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.teal,
                    ),
                  )
                else
                  const Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 16,
                    color: AppColors.teal,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
