import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'auth_scaffold.dart';

class VerifySignupPage extends ConsumerStatefulWidget {
  final String? token;
  const VerifySignupPage({super.key, this.token});

  @override
  ConsumerState<VerifySignupPage> createState() => _VerifySignupPageState();
}

class _VerifySignupPageState extends ConsumerState<VerifySignupPage> {
  bool _linkStale = false;
  bool _verified = false;

  Future<void> _verify() async {
    try {
      await ref.read(authProvider.notifier).verifySignup(widget.token!);
      if (!mounted) return;
      setState(() => _verified = true);
      AppMessenger.success('Account verified! Welcome to Enervara.');
      // The router redirects to /onboarding (or /dashboard) once authenticated.
    } catch (e) {
      final msg = e.toString();
      if (RegExp('invalid|expired', caseSensitive: false).hasMatch(msg)) {
        if (mounted) setState(() => _linkStale = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final hasToken = token != null && token.isNotEmpty;

    if (!hasToken || _linkStale) return _invalid(context, hasToken);
    if (_verified) return _success(context);

    final isLoading = ref.watch(authProvider).isLoading;
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
            title: 'Verify your account',
            subtitle:
                'Click the button below to finish creating your Enervara account.',
            centered: true,
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Verify my account',
            height: 48,
            loading: isLoading,
            onPressed: _verify,
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
          const AuthHeader(title: 'Account verified', centered: true),
          const SizedBox(height: 10),
          Text(
            'Welcome to Enervara. Taking you in…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: t.ink2),
          ),
        ],
      ),
    );
  }

  Widget _invalid(BuildContext context, bool hasToken) {
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
          AuthHeader(
            title:
                hasToken ? 'Link no longer valid' : 'Invalid verification link',
            centered: true,
          ),
          const SizedBox(height: 10),
          Text(
            hasToken
                ? 'This verification link has expired or already been used. '
                    'Sign up again to receive a new one.'
                : 'This link is missing a token. Sign up again to request a new one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: t.ink2),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Back to sign up',
            height: 48,
            onPressed: () => context.go('/signup'),
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
