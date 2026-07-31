import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/google_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'auth_scaffold.dart';
import 'auth_scene.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      if (!mounted) return;
      AppMessenger.success('Welcome back!');
      // The router redirects to /dashboard once authenticated.
    } catch (_) {
      // The API client already surfaced the error toast.
    }
  }

  Future<void> _google() async {
    try {
      final signedIn = await ref.read(authProvider.notifier).googleSignIn();
      // Canceled picker — say nothing. Claiming success here would leave the
      // user staring at "Welcome back" on a screen that never navigates.
      if (!mounted || !signedIn) return;
      AppMessenger.success('Welcome back!');
      // The router redirects once authenticated (new users continue to
      // onboarding; returning users go straight to /dashboard).
    } on GoogleAuthFailure catch (e) {
      // Never reaches the API client, so nothing else would surface it.
      AppMessenger.error(e.message);
    } catch (_) {
      // Backend rejection — the API client already surfaced the error toast.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    return AuthScene(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Welcome back',
            subtitle: 'Sign in to continue to Enervara',
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
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: 15),
                AuthField(
                  controller: _password,
                  label: 'Password',
                  hint: '••••••••',
                  password: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.password,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.push('/forgot-password'),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealD,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Sign In',
                  height: 48,
                  loading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const AuthOrDivider(),
          AuthGoogleButton(onPressed: _google, disabled: isLoading),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: "Don't have an account?",
            action: 'Sign up',
            onTap: () => context.go('/signup'),
          ),
        ],
      ),
    );
  }
}
