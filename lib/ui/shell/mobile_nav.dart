import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/context_ext.dart';
import '../../data/constants/navigation.dart';
import '../widgets/logo.dart';

/// Bottom tab bar — Home · Speciality · [Nova] · History · Reports.
/// Nova is a raised circular action that breaks out above the bar.
class MobileNav extends StatelessWidget {
  final String currentPath;
  const MobileNav({super.key, required this.currentPath});

  /// Extra room above the bar so the raised Nova button isn't clipped.
  static const overhang = 28.0;

  bool _isActive(String path) {
    if (path == '/dashboard') return currentPath == '/dashboard';
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    // Tab content height, tightened by 15px so there's less empty space
    // between the icons/labels and the bar's bottom edge.
    final barHeight = 47.0 + safeBottom;

    return SizedBox(
      height: barHeight + overhang,
      // clipBehavior none → the raised Nova button can paint above the bar.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── The bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: barHeight,
              padding: EdgeInsets.only(bottom: safeBottom),
              decoration: BoxDecoration(
                color: t.card,
                border: Border(top: BorderSide(color: t.line)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (final item in kMobileNavLeft)
                    _NavTab(item: item, active: _isActive(item.path)),
                  // Centre slot — empty; the raised Nova button floats over it.
                  const Spacer(),
                  for (final item in kMobileNavRight)
                    _NavTab(item: item, active: _isActive(item.path)),
                ],
              ),
            ),
          ),

          // ── Raised Nova action ──
          Positioned(
            left: 0,
            right: 0,
            bottom: barHeight - 40,
            child: Center(
              child: GestureDetector(
                onTap: () => context.push('/nova'),
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: AppGradients.miniBrand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(child: Logo(size: 33, white: true)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final NavItem item;
  final bool active;
  const _NavTab({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(item.path),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? item.iconFill : item.icon,
              size: 24,
              color: active ? AppColors.teal : t.ink3,
            ),
            const SizedBox(height: 2),
            Text(
              item.shortLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.teal : t.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
