import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../widgets/logo.dart';

/// Full-screen boot splash shown while auth state hydrates.
class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.appBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Logo(size: 64),
            const SizedBox(height: 18),
            Text(
              'Enervara',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.tealD),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
            ),
          ],
        ),
      ),
    );
  }
}
