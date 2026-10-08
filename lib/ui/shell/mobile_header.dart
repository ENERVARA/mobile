import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/context_ext.dart';
import '../../state/nova_ui_provider.dart';
import '../../state/shell_ui_provider.dart';
import '../tour/tour_keys.dart';
import '../widgets/logo.dart';

/// Fixed mobile top header — hamburger, emergency, centred brand, Nova.
/// Ported from `MobileHeader.tsx`. Dark mode lives in the drawer the hamburger
/// opens (above the Profile row), not here — one toggle, not two.
class MobileHeader extends ConsumerWidget {
  const MobileHeader({super.key});

  /// `--nav-h` (55px) — the bar's own height, excluding the status-bar inset.
  static const barHeight = 55.0;

  static double heightOf(BuildContext context) =>
      barHeight + MediaQuery.viewPaddingOf(context).top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final novaOpen = ref.watch(novaUiProvider.select((s) => s.open));

    return Container(
      height: barHeight + topPad,
      padding: EdgeInsets.only(top: topPad, left: 12, right: 12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left actions + right Nova button
          Row(
            children: [
              _SquareButton(
                semanticLabel: 'Open menu',
                bg: t.soft,
                onTap: () {
                  // The drawer and Nova panel never show together.
                  ref.read(shellUiProvider.notifier).toggleDrawer();
                },
                child: Icon(PhosphorIconsRegular.list, size: 18.4, color: t.ink2),
              ),
              const SizedBox(width: 6),
              _SquareButton(
                semanticLabel: 'Emergency',
                bg: AppColors.coral.withValues(alpha: 0.1),
                onTap: () {
                  ref.read(shellUiProvider.notifier).closeDrawer();
                  context.go('/emergency');
                },
                child: const Icon(PhosphorIconsFill.phoneCall, size: 18.4, color: AppColors.coral),
              ),
              const Spacer(),
              GestureDetector(
                key: TourKeys.of('nova-orb-mobile'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(shellUiProvider.notifier).closeDrawer();
                  final nova = ref.read(novaUiProvider.notifier);
                  if (novaOpen) {
                    nova.closeChat();
                  } else {
                    nova.openChat();
                  }
                },
                child: Semantics(
                  label: 'Open Nova AI',
                  button: true,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppGradients.miniBrand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Logo(size: 22, white: true),
                  ),
                ),
              ),
            ],
          ),
          // Centred brand — never intercepts taps.
          IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(size: 28),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Enervara'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Transform.translate(
                          // `relative -top-[0.2em] ml-[2px] text-[0.8em]`
                          offset: const Offset(2, -2.43),
                          child: const Text(
                            '™',
                            style: TextStyle(
                              fontSize: 12.16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tealD,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealD,
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

class _SquareButton extends StatelessWidget {
  final Color bg;
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  const _SquareButton({
    required this.bg,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
