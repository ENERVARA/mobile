import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/context_ext.dart';
import '../../widgets/logo.dart';

/// Full-screen shell for every auth page: a brand-gradient header with the
/// logo + "Enervara" wordmark, then a rounded card that holds the form.
/// Scrollable and keyboard-safe (the card lifts above the keyboard).
///
/// When [animate] is true (the login page only) it plays a one-shot entrance:
/// the brand header drops in from above while the form card flies up from
/// below — the mobile counterpart of the web login page's `as-flyUp` + logo
/// drop-in.
class AuthScaffold extends StatefulWidget {
  final Widget child;
  final bool animate;
  const AuthScaffold({super.key, required this.child, this.animate = false});

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );

  // Brand header: slide down from above + fade, front-loaded.
  late final Animation<double> _headerFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
  );
  late final Animation<Offset> _headerSlide = Tween(
    begin: const Offset(0, -0.55),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
  ));

  // Form card: fly up from below + fade, slightly delayed (as-flyUp).
  late final Animation<double> _cardFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.9, curve: Curves.easeOut),
  );
  late final Animation<Offset> _cardSlide = Tween(
    begin: const Offset(0, 0.28),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 1.0, curve: Curves.easeOutCubic),
  ));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1; // static: fully settled, no animation
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 40),
      decoration: const BoxDecoration(
        gradient: AppGradients.brandDiagonal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Logo(size: 44, white: true),
          SizedBox(height: 12),
          Text(
            'Enervara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );

    final card = Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: widget.child,
      ),
    );

    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // ── Brand gradient header (drops in) ──
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(position: _headerSlide, child: header),
              ),
              // ── Form card (flies up) ──
              FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(position: _cardSlide, child: card),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card title + optional subtitle. Set [centered] for the success/error states.
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool centered;
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: t.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.ink2),
          ),
        ],
      ],
    );
  }
}

/// Labelled text field matching the web `.login-input`: 48-ish tall, hairline
/// border, teal focus ring, with an optional show/hide toggle for passwords.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool password;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final List<String>? autofillHints;
  final String? errorText;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '',
    this.password = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.errorText,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.password && _obscure,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          cursorColor: AppColors.teal,
          style: TextStyle(fontSize: 15.5, color: t.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: 15.5, color: t.ink3),
            filled: true,
            fillColor: t.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: widget.password
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? PhosphorIconsRegular.eye
                          : PhosphorIconsRegular.eyeSlash,
                      size: 20,
                      color: t.ink3,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            enabledBorder: _border(t.line, 1),
            focusedBorder: _border(AppColors.teal, 1.6),
            errorBorder: _border(AppColors.danger, 1),
            focusedErrorBorder: _border(AppColors.danger, 1.6),
            errorStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
            errorText: widget.errorText,
          ),
        ),
      ],
    );
  }
}

/// The "─ or ─" divider between the primary button and Google sign-in.
/// Centered footer prompt: "prefix" + a tappable teal "action".
class AuthFooterLink extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;
  const AuthFooterLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: TextStyle(fontSize: 13.8, color: t.ink2)),
        const SizedBox(width: 5),
        _LinkText(action, onTap),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _LinkText(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.8,
          fontWeight: FontWeight.w600,
          color: AppColors.tealD,
        ),
      ),
    );
  }
}

/// A round tinted circle holding a status icon (success = teal, error = coral).
class AuthStatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const AuthStatusIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: color),
    );
  }
}

/// Slim password-strength bar, mirroring the web `getPasswordStrength` util.
class AuthPasswordStrengthBar extends StatelessWidget {
  final String value;
  const AuthPasswordStrengthBar({super.key, required this.value});

  static ({String label, Color color, double pct}) _strength(String pw) {
    if (pw.isEmpty) return (label: '', color: Colors.transparent, pct: 0);
    if (pw.length < 6) return (label: 'Weak', color: AppColors.danger, pct: 0.25);
    if (pw.length < 10) return (label: 'Fair', color: AppColors.warning, pct: 0.50);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pw);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pw);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    if (hasUpper && hasNumber && hasSpecial) {
      return (label: 'Strong', color: AppColors.success, pct: 1);
    }
    return (label: 'Fair', color: AppColors.warning, pct: 0.65);
  }

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final s = _strength(value);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.pct,
                minHeight: 4,
                backgroundColor: t.soft,
                valueColor: AlwaysStoppedAnimation(s.color),
              ),
            ),
          ),
          if (s.label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              s.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: s.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
