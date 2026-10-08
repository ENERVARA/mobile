import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/context_ext.dart';

/// The web `Modal` primitive at mobile width: a centred card (`rounded-[24px]`,
/// `p-8`, `max-w-lg`) over a 50% black, 4px-blurred backdrop, with a round
/// 40px close chip in its top-right corner. Ported from `components/ui/Modal.tsx`.
///
/// Returns whatever the content passes to `Navigator.pop`.
///
/// When [onDismissRequest] is given, a backdrop tap / back press / close-chip tap
/// calls it instead of popping automatically — the content decides whether (and
/// when) to close, e.g. refusing to dismiss mid-upload.
Future<T?> showAppModal<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  double maxWidth = 512,
  EdgeInsets padding = const EdgeInsets.all(32),
  bool dismissible = true,
  bool showClose = true,
  VoidCallback? onDismissRequest,
  double radius = 24,
  bool bordered = false,
  double scrim = 0.5,
  double blur = 4,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: scrim),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) => AppModalFrame(
      title: title,
      maxWidth: maxWidth,
      padding: padding,
      dismissible: dismissible,
      showClose: showClose,
      onDismissRequest: onDismissRequest,
      radius: radius,
      bordered: bordered,
      blur: blur,
      child: Builder(builder: builder),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// The round 40px close control (`grid size-10 rounded-full border`) — filled so
/// it reads as a control in both themes.
class ModalCloseChip extends StatelessWidget {
  final VoidCallback? onTap;
  const ModalCloseChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final chipBg = dark ? const Color(0xFF1C1C1F) : const Color(0xFFF0F2F5);
    final chipBorder = dark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E8EB);
    final chipFg = dark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    return Semantics(
      label: 'Close',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: chipBg,
            shape: BoxShape.circle,
            border: Border.all(color: chipBorder),
          ),
          alignment: Alignment.center,
          child: Icon(PhosphorIconsBold.x, size: 20, color: chipFg),
        ),
      ),
    );
  }
}

class AppModalFrame extends StatelessWidget {
  final String? title;
  final double maxWidth;
  final EdgeInsets padding;
  final bool dismissible;
  final bool showClose;
  final VoidCallback? onDismissRequest;
  final double radius;
  final bool bordered;
  final double blur;
  final Widget child;

  const AppModalFrame({
    super.key,
    this.title,
    this.maxWidth = 512,
    this.padding = const EdgeInsets.all(32),
    this.dismissible = true,
    this.showClose = true,
    this.onDismissRequest,
    this.radius = 24,
    this.bordered = false,
    this.blur = 4,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    // Legacy `--color-surface*` tokens.
    final surface = dark ? const Color(0xFF141416) : Colors.white;
    final titleColor = dark ? const Color(0xFFF4F4F5) : const Color(0xFF111827);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenH = MediaQuery.sizeOf(context).height;

    void requestDismiss() {
      if (onDismissRequest != null) {
        onDismissRequest!();
      } else if (dismissible) {
        // Not maybePop(): this dialog's own PopScope below reports
        // canPop:false (so it can intercept the Android back button and route
        // it through this same requestDismiss), and maybePop() respects that
        // flag — calling it here would just re-fire onPopInvokedWithResult,
        // which calls requestDismiss again, forever. pop() is unconditional
        // and bypasses canPop, so it actually closes the dialog.
        Navigator.of(context).pop();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) requestDismiss();
      },
      child: Stack(
        children: [
          // backdrop-filter: blur(4px) over the dim barrier.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: requestDismiss,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: screenH * 0.92),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(radius),
                      border: bordered ? Border.all(color: context.tokens.line) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 50,
                          offset: const Offset(0, 25),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Material(
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              padding: padding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (title != null)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 8, right: showClose ? 48 : 0),
                                      child: Text(
                                        title!,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4,
                                          color: titleColor,
                                        ),
                                      ),
                                    ),
                                  child,
                                ],
                              ),
                            ),
                            if (showClose)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: ModalCloseChip(onTap: requestDismiss),
                              ),
                          ],
                        ),
                      ),
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
