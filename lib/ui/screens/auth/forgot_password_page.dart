import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'auth_scaffold.dart';
import 'resend_link.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _sent = false;
  String _sentEmail = '';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    try {
      await ref.read(authProvider.notifier).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _sentEmail = email;
        _sent = true;
      });
    } catch (_) {
      // The API client already surfaced the error toast.
    }
  }

  Future<void> _resend() async {
    if (_sentEmail.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).forgotPassword(_sentEmail);
    } catch (_) {
      // handled by the API client interceptor
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    if (_sent) return _success(context);

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Forgot password?',
            subtitle: "Enter your email and we'll send you a reset link.",
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  controller: _email,
                  label: 'Email address',
                  hint: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: _emailValidator,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Send Reset Link',
                  height: 48,
                  loading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'Remember your password?',
            action: 'Sign in',
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }

  static String? _emailValidator(String? v) {
    final value = v?.trim() ?? '';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    if (!ok) return 'Please enter a valid email address';
    return null;
  }

  Widget _success(BuildContext context) {
    final t = context.tokens;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AuthStatusIcon(
            icon: PhosphorIconsDuotone.checkCircle,
            color: AppColors.teal,
          ),
          const SizedBox(height: 22),
          const AuthHeader(
            title: 'Check your email',
            centered: true,
          ),
          const SizedBox(height: 10),
          Text(
            'If that email exists, a reset link was sent to',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: t.ink2),
          ),
          const SizedBox(height: 4),
          Text(
            _sentEmail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.2,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Didn't receive it? Check spam, or",
                  style: TextStyle(fontSize: 13.3, color: t.ink3)),
              const SizedBox(width: 5),
              ResendLink(onResend: _resend, label: 'resend the link'),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _sent = false),
            child: Text(
              'Try a different address',
              style: TextStyle(
                fontSize: 13.3,
                fontWeight: FontWeight.w600,
                color: t.ink3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: '',
            action: 'Back to login',
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
