import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/context_ext.dart';
import '../../state/nova_ui_provider.dart';
import '../../state/shell_ui_provider.dart';
import '../screens/nova/nova_panel.dart';
import 'mobile_drawer.dart';
import 'mobile_header.dart';
import 'mobile_nav.dart';

/// The persistent mobile app frame — ported from `DashboardLayout.tsx` at
/// mobile width: a fixed header on top, the routed page, a bottom tab bar, an
/// off-canvas drawer (z above the tab bar, scrim dimming everything but the
/// header) and the Nova chat overlay that slides in from the right *under* the
/// header.
///
/// Stacking order (matches the web z-indexes): page · tab bar (290) · Nova panel
/// (350) · drawer scrim (390) · drawer (400) · header (450).
class AppShell extends ConsumerStatefulWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with TickerProviderStateMixin {
  // `transition-[left]` (150ms) for the drawer, `ease-spring` 350ms for Nova.
  late final AnimationController _drawer =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  late final AnimationController _nova =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  // framer-motion page enter: opacity 0→1 + y 10→0 over 0.18s.
  late final AnimationController _page =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180), value: 1);

  static const _spring = Cubic(0.22, 1, 0.36, 1);

  @override
  void didUpdateWidget(covariant AppShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      _page.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawer.dispose();
    _nova.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final headerH = MobileHeader.heightOf(context);

    ref.listen<bool>(shellUiProvider.select((s) => s.drawerOpen), (_, open) {
      open ? _drawer.forward() : _drawer.reverse();
    });
    ref.listen<bool>(novaUiProvider.select((s) => s.open), (_, open) {
      open ? _nova.forward() : _nova.reverse();
    });

    final drawerOpen = ref.watch(shellUiProvider.select((s) => s.drawerOpen));
    final novaOpen = ref.watch(novaUiProvider.select((s) => s.open));

    return PopScope(
      // Android back closes the topmost overlay before leaving the page.
      canPop: !(drawerOpen || novaOpen),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (drawerOpen) {
          ref.read(shellUiProvider.notifier).closeDrawer();
        } else if (novaOpen) {
          ref.read(novaUiProvider.notifier).closeChat();
        }
      },
      child: Scaffold(
        backgroundColor: t.appBg,
        // The shell handles its own insets (header + tab bar absorb them).
        resizeToAvoidBottomInset: false,
        // Every child is Positioned, so without `expand` the Stack would shrink to
        // 0×0 under the Scaffold's loose constraints and the page would get no
        // size at all (the header/tab bar still paint, hence a "blank" app).
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── The routed page, under the header ──
            Positioned(
              top: headerH,
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _page,
                builder: (context, child) {
                  final k = Curves.easeOut.transform(_page.value);
                  return Opacity(
                    opacity: k,
                    child: Transform.translate(offset: Offset(0, 10 * (1 - k)), child: child),
                  );
                },
                child: widget.child,
              ),
            ),

            // ── Bottom tab bar ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MobileNav(currentPath: widget.location),
            ),

            // ── Nova chat overlay (under the header, above the tab bar) ──
            AnimatedBuilder(
              animation: _nova,
              builder: (context, _) {
                if (!novaOpen && _nova.isDismissed) return const SizedBox.shrink();
                final slide = _spring.transform(_nova.value);
                return Positioned(
                  top: headerH,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FractionalTranslation(
                    translation: Offset(1.05 * (1 - slide), 0),
                    child: const NovaPanel(),
                  ),
                );
              },
            ),

            // ── Drawer scrim + drawer ──
            AnimatedBuilder(
              animation: _drawer,
              builder: (context, _) {
                if (!drawerOpen && _drawer.isDismissed) return const SizedBox.shrink();
                final k = Curves.fastOutSlowIn.transform(_drawer.value);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref.read(shellUiProvider.notifier).closeDrawer(),
                        child: ColoredBox(color: Colors.black.withValues(alpha: 0.4 * k)),
                      ),
                    ),
                    Positioned(
                      top: headerH,
                      bottom: 0,
                      left: -MobileDrawer.width * (1 - k),
                      width: MobileDrawer.width,
                      child: MobileDrawer(currentPath: widget.location),
                    ),
                  ],
                );
              },
            ),

            // ── Header (always on top) ──
            const Positioned(top: 0, left: 0, right: 0, child: MobileHeader()),
          ],
        ),
      ),
    );
  }
}
