import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
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

  String? _emailError;
  String? _passwordError;

  void _clearErrors() {
    if (_emailError != null || _passwordError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
    }
  }

  void _showSignupDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final t = context.tokens;
        return AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Account Not Found',
            style: TextStyle(color: t.ink, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "We couldn't find an account for ${_email.text.trim()}.\nWould you like to create one?",
            style: TextStyle(color: t.ink2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: t.ink3)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/signup');
              },
              child: const Text('Sign Up'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    _clearErrors();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      if (!mounted) return;
      AppMessenger.success('Welcome back!');
      // The router redirects to /dashboard once authenticated.
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = (data is Map ? data['message']?.toString() : null) ?? '';
      final lowerMsg = msg.toLowerCase();
      
      if (lowerMsg.contains('user') || lowerMsg.contains('account') || lowerMsg.contains('found') || lowerMsg.contains('record')) {
        setState(() => _emailError = 'Account not found');
        _showSignupDialog();
      } else if (lowerMsg.contains('password')) {
        setState(() => _passwordError = 'Incorrect password');
      } else if (lowerMsg.contains('invalid') || lowerMsg.contains('credential')) {
        setState(() {
          _emailError = 'Invalid email or password';
          _passwordError = 'Invalid email or password';
        });
      } else {
        AppMessenger.error(msg.isNotEmpty ? msg : 'Login failed');
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.error(e.toString());
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
                  onChanged: (_) => _clearErrors(),
                  errorText: _emailError,
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
                  onChanged: (_) => _clearErrors(),
                  errorText: _passwordError,
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
