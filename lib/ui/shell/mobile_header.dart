import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/context_ext.dart';
import '../../state/auth_provider.dart';
import '../../state/theme_provider.dart';
import '../widgets/logo.dart';

/// Fixed mobile top header — dark-mode + emergency on the left, the centred
/// brand, and the profile avatar on the right.
class MobileHeader extends ConsumerWidget implements PreferredSizeWidget {
  const MobileHeader({super.key});

  static const _barHeight = 55.0;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final user = ref.watch(authProvider).user;

    Widget squareButton({
      required IconData icon,
      required VoidCallback onTap,
      Color? bg,
      Color? fg,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg ?? t.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: fg ?? t.ink2),
        ),
      );
    }

    return Container(
      height: _barHeight + topPad,
      padding: EdgeInsets.only(top: topPad, left: 12, right: 12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centred brand
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Logo(size: 28),
              const SizedBox(width: 8),
              Text(
                'Enervara',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealD,
                ),
              ),
            ],
          ),
          // Left actions + right profile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  squareButton(
                    icon: isDark ? PhosphorIconsRegular.sun : PhosphorIconsRegular.moon,
                    onTap: () => ref.read(themeProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 6),
                  squareButton(
                    icon: PhosphorIconsFill.phoneCall,
                    bg: AppColors.coral.withValues(alpha: 0.1),
                    fg: AppColors.coral,
                    onTap: () => context.push('/emergency'),
                  ),
                ],
              ),
              // Profile
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.miniBrand,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initial ?? 'U',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
