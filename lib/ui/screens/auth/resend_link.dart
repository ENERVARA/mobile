import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';

/// "Resend link" action with the web's 60-second cooldown (`useResend`), so
/// repeated taps can't trip the backend's auth rate-limiter.
class ResendLink extends StatefulWidget {
  final String label;
  final Future<void> Function() onResend;
  const ResendLink({super.key, required this.onResend, this.label = 'Resend link'});

  @override
  State<ResendLink> createState() => _ResendLinkState();
}

class _ResendLinkState extends State<ResendLink> {
  static const _cooldown = 60;

  Timer? _timer;
  int _remaining = 0;
  bool _sending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _remaining = _cooldown);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) t.cancel();
    });
  }

  Future<void> _handle() async {
    if (_sending || _remaining > 0) return;
    setState(() => _sending = true);
    try {
      await widget.onResend();
      if (mounted) _startCooldown();
    } catch (_) {
      /* the API interceptor already toasted */
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = _sending || _remaining > 0;
    final text = _sending
        ? 'Sending…'
        : _remaining > 0
            ? 'Resend in ${_remaining}s'
            : widget.label;

    return GestureDetector(
      onTap: disabled ? null : _handle,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.6,
          fontWeight: FontWeight.w600,
          color: disabled ? t.ink3 : AppColors.tealD,
        ),
      ),
    );
  }
}
