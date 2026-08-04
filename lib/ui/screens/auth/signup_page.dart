import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'auth_scaffold.dart';
import 'auth_scene.dart';
import 'resend_link.dart';

final _phoneRegex = RegExp(r'^[+\d\s\-()/.]{7,20}$');

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _sent = false;
  String _pwValue = '';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authProvider.notifier).requestSignup(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      setState(() => _sent = true);
      AppMessenger.success('Verification link sent to ${_email.text.trim()}');
    } catch (_) {
      // The API client already surfaced the error toast.
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authProvider.notifier).requestSignup(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      AppMessenger.success('Verification link resent');
    } catch (_) {
      // handled by the API client interceptor
    }
  }

  String? _phoneValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Please enter a valid mobile number';
    if (!_phoneRegex.hasMatch(value)) {
      return 'Please enter a valid mobile number';
    }
    return null;
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    if (_sent) return _checkEmail(context, isLoading);

    return AuthScene(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Create your account',
            subtitle: 'Join Enervara — Nova is ready when you are.',
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AuthField(
                        controller: _firstName,
                        label: 'First name',
                        hint: 'Jane',
                        autofillHints: const [AutofillHints.givenName],
                        validator: (v) => Validators.required(v, 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthField(
                        controller: _lastName,
                        label: 'Last name',
                        hint: 'Doe',
                        autofillHints: const [AutofillHints.familyName],
                        validator: (v) => Validators.required(v, 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _phone,
                  label: 'Mobile number',
                  hint: '+1 555 000 0000',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _email,
                  label: 'Email address',
                  hint: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _password,
                  label: 'Create password',
                  hint: '••••••••',
                  password: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  onChanged: (v) => setState(() => _pwValue = v),
                ),
                AuthPasswordStrengthBar(value: _pwValue),
                const SizedBox(height: 12),
                AuthField(
                  controller: _confirm,
                  label: 'Confirm password',
                  hint: '••••••••',
                  password: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _confirmValidator,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Create Account',
                  height: 48,
                  loading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AuthFooterLink(
            prefix: 'Already have an account?',
            action: 'Sign in',
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }

  Widget _checkEmail(BuildContext context, bool isLoading) {
    final t = context.tokens;
    final email =
        ref.watch(authProvider).pendingSignupEmail ?? _email.text.trim();
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AuthStatusIcon(
            icon: PhosphorIconsDuotone.envelopeOpen,
            color: AppColors.teal,
          ),
          const SizedBox(height: 22),
          const AuthHeader(
            title: 'Check your email',
            subtitle: "We've sent a verification link to",
            centered: true,
          ),
          const SizedBox(height: 3),
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.2,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Click the link in the email to finish creating your account. '
            'The link expires in 30 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.6, height: 1.45, color: t.ink2),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Didn't get the email?",
                  style: TextStyle(fontSize: 13.6, color: t.ink2)),
              const SizedBox(width: 5),
              ResendLink(onResend: _resend),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _sent = false),
            child: Text(
              'Change details',
              style: TextStyle(fontSize: 13, color: t.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
