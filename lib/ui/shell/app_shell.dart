import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';
import 'mobile_header.dart';
import 'mobile_nav.dart';

/// The persistent mobile app frame: fixed header + body + bottom tab bar.
/// The nav is overlaid via a Stack (rather than `bottomNavigationBar`) so the
/// raised centre Nova button can paint and hit-test above the bar.
class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.appBg,
      appBar: const MobileHeader(),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MobileNav(currentPath: location),
          ),
        ],
      ),
    );
  }
}
