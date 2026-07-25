import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Global messenger for toast-style feedback, mirroring the web app's Sonner
/// toasts (the Axios interceptor auto-toasts errors — see api_client.dart).
class AppMessenger {
  AppMessenger._();

  static final key = GlobalKey<ScaffoldMessengerState>();

  static void _show(String message, {required Color bg, required IconData icon}) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  static void error(String message) =>
      _show(message, bg: AppColors.coral, icon: Icons.error_outline);

  static void success(String message) =>
      _show(message, bg: AppColors.teal, icon: Icons.check_circle_outline);

  static void info(String message) =>
      _show(message, bg: AppColors.cyan, icon: Icons.info_outline);
}
