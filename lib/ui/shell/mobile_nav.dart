import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../../data/constants/navigation.dart';
import '../../state/shell_ui_provider.dart';
import '../tour/tour_keys.dart';

/// Mobile bottom tab bar — Home · Care · Wellness · Timeline · Records.
/// Ported from `MobileNav.tsx` (`h = 62px + safe-area`, top hairline, soft
/// upward shadow).
class MobileNav extends ConsumerWidget {
  final String currentPath;
  const MobileNav({super.key, required this.currentPath});

  /// Tab-bar content height, excluding the bottom safe-area inset.
  static const barHeight = 62.0;

  static bool isActivePath(String currentPath, String path) =>
      currentPath == path || currentPath.startsWith('$path/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      height: barHeight + safeBottom,
      padding: EdgeInsets.only(left: 4, right: 4, bottom: safeBottom),
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
          for (final item in kMobileNavItems)
            _NavTab(
              item: item,
              active: isActivePath(currentPath, item.path),
              onTap: () {
                ref.read(shellUiProvider.notifier).closeDrawer();
                context.go(item.path);
              },
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavTab({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? AppColors.teal : t.ink3;
    return Expanded(
      child: Center(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: TourKeys.of('m-nav-${item.key}'),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active ? item.iconFill : item.icon, size: 20.8, color: color),
                    const SizedBox(height: 2),
                    Text(
                      item.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 9.92,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
