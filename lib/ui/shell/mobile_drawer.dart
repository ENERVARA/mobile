import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../../core/utils/formatters.dart';
import '../../data/constants/navigation.dart';
import '../../state/auth_provider.dart';
import '../../state/nova_ui_provider.dart';
import '../../state/shell_ui_provider.dart';
import '../../state/theme_provider.dart';
import '../tour/tour_keys.dart';
import '../widgets/logo.dart';
import '../widgets/nova_orb.dart';
import 'mobile_nav.dart';

/// The off-canvas navigation drawer (the web `Sidebar` at mobile width):
/// Nova orb → nav → theme toggle → Profile. `220px` wide, sits under the header.
class MobileDrawer extends ConsumerWidget {
  final String currentPath;
  const MobileDrawer({super.key, required this.currentPath});

  static const width = 220.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(authProvider.select((s) => s.user));
    final isDark = ref.watch(themeProvider) == ThemeMode.dark ||
        (ref.watch(themeProvider) == ThemeMode.system && context.isDark);
    final displayName = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join(' ');
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    void closeDrawer() => ref.read(shellUiProvider.notifier).closeDrawer();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Nova section ──
          _NovaSection(
            onTap: () {
              final nova = ref.read(novaUiProvider.notifier);
              final open = ref.read(novaUiProvider).open;
              closeDrawer();
              if (open) {
                nova.closeChat();
              } else {
                nova.openChat();
              }
            },
          ),

          // ── Nav ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + safeBottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 16 - safeBottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < kNavItems.length; i++) ...[
                          if (i > 0) const SizedBox(height: 2),
                          _DrawerNavRow(
                            item: kNavItems[i],
                            active: MobileNav.isActivePath(currentPath, kNavItems[i].path),
                            onTap: () {
                              closeDrawer();
                              context.go(kNavItems[i].path);
                            },
                          ),
                        ],
                        const Spacer(),

                        // Theme toggle — a nav-list row with a trailing switch.
                        _ThemeToggleRow(
                          isDark: isDark,
                          onTap: () => ref.read(themeProvider.notifier).toggle(),
                        ),

                        // Profile is an account destination, anchored apart.
                        const SizedBox(height: 8),
                        InkWell(
                          key: TourKeys.of('nav-profile'),
                          onTap: () {
                            closeDrawer();
                            context.go(kProfileNavItem.path);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 13, 8, 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: AppColors.teal,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    Formatters.initialsOf(user?.firstName, user?.lastName),
                                    style: const TextStyle(
                                      fontSize: 14.4,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        displayName.isEmpty ? 'Your account' : displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.4,
                                          fontWeight: FontWeight.w600,
                                          color: t.ink,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'My account',
                                            style: TextStyle(fontSize: 12.16, color: t.ink3),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(PhosphorIconsRegular.caretRight,
                                              size: 11.2, color: t.ink3),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerNavRow extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _DrawerNavRow({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final fg = active ? (dark ? AppColors.teal : AppColors.tealD) : t.ink2;
    return Material(
      color: active ? AppColors.teal.withValues(alpha: dark ? 0.15 : 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Icon(
                  active ? item.iconFill : item.icon,
                  size: 18.4,
                  color: active ? AppColors.teal : fg,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.92,
                    height: 1.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _ThemeToggleRow({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Icon(
                  isDark ? PhosphorIconsRegular.moon : PhosphorIconsRegular.sun,
                  size: 18.4,
                  color: t.ink2,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isDark ? 'Dark mode' : 'Light mode',
                  style: TextStyle(
                    fontSize: 13.92,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: t.ink2,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.teal : t.line,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isDark ? const Alignment(0.72, 0) : const Alignment(-0.72, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nova's block at the top of the drawer: breathing glow + dot-sphere orb +
/// gradient logo, then "Nova" / "Click to chat".
class _NovaSection extends StatelessWidget {
  final VoidCallback onTap;
  const _NovaSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Column(
          children: [
            SizedBox(
              width: 140,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _BreathingGlow(size: 110),
                  const NovaOrb(preset: OrbPreset.sidebar),
                  const Logo(size: 22),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nova',
              style: TextStyle(fontSize: 14.08, fontWeight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: 3),
            Text(
              'Click to chat',
              style: TextStyle(fontSize: 11.2, color: t.ink3, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.orb-glow-teal` + `animate-breathe` (4s ease-in-out, scale 1→1.08, opacity .7→1).
class _BreathingGlow extends StatefulWidget {
  final double size;
  const _BreathingGlow({required this.size});

  @override
  State<_BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<_BreathingGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    // CSS radial-gradient(circle) sizes to the farthest corner (r = half-diagonal).
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      builder: (context, _) {
        final k = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: 0.7 + 0.3 * k,
          child: Transform.scale(
            scale: 1 + 0.08 * k,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  radius: 0.7071,
                  colors: dark
                      ? const [Color(0x400BB5A6), Color(0x1A0BB5A6), Color(0x000BB5A6)]
                      : const [Color(0x2E0BB5A6), Color(0x122CB0C8), Color(0x002CB0C8)],
                  stops: const [0, 0.55, 0.75],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
