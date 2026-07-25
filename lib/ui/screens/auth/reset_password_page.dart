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

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? token;
  const ResetPasswordPage({super.key, this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _pwValue = '';
  bool _linkStale = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(widget.token!, _password.text);
      if (!mounted) return;
      AppMessenger.success('Password updated. You are signed in.');
      // The router redirects to /dashboard once authenticated.
    } catch (e) {
      final msg = e.toString();
      if (RegExp('invalid|expired', caseSensitive: false).hasMatch(msg)) {
        if (mounted) setState(() => _linkStale = true);
      }
    }
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) return _invalidLink(context);

    final isLoading = ref.watch(authProvider).isLoading;
    final t = context.tokens;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Set a new password',
            subtitle: 'Choose a new password for your Enervara account.',
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  controller: _password,
                  label: 'New password',
                  hint: 'At least 8 characters',
                  password: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  onChanged: (v) => setState(() => _pwValue = v),
                ),
                AuthPasswordStrengthBar(value: _pwValue),
                const SizedBox(height: 15),
                AuthField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  hint: 'Re-enter your password',
                  password: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _confirmValidator,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Update password',
                  height: 48,
                  loading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          if (_linkStale) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('This link is no longer valid.',
                      style: TextStyle(fontSize: 13.3, color: t.ink2)),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => context.push('/forgot-password'),
                    child: const Text(
                      'Request a new one',
                      style: TextStyle(
                        fontSize: 13.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealD,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _invalidLink(BuildContext context) {
    final t = context.tokens;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AuthStatusIcon(
            icon: PhosphorIconsDuotone.warning,
            color: AppColors.coral,
          ),
          const SizedBox(height: 22),
          const AuthHeader(title: 'Invalid reset link', centered: true),
          const SizedBox(height: 10),
          Text(
            'This link is missing a token. Request a new one from the login page.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: t.ink2),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Request a new link',
            height: 48,
            onPressed: () => context.push('/forgot-password'),
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
