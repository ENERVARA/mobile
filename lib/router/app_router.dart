import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../state/first_run_provider.dart';
import '../ui/shell/app_shell.dart';
import '../ui/shell/boot_splash.dart';
import '../ui/screens/auth/login_page.dart';
import '../ui/screens/auth/signup_page.dart';
import '../ui/screens/auth/forgot_password_page.dart';
import '../ui/screens/auth/reset_password_page.dart';
import '../ui/screens/auth/verify_signup_page.dart';
import '../ui/screens/onboarding/onboarding_page.dart';
import '../ui/screens/dashboard/dashboard_page.dart';
import '../ui/screens/specialities/specialities_page.dart';
import '../ui/screens/specialities/speciality_detail_page.dart';
import '../ui/screens/history/history_page.dart';
import '../ui/screens/reports/reports_page.dart';
import '../ui/screens/reports/report_detail_page.dart';
import '../ui/screens/profile/profile_page.dart';
import '../ui/screens/emergency/emergency_page.dart';
import '../ui/screens/nova/nova_chat_page.dart';
import '../ui/screens/about/about_page.dart';
import '../ui/screens/welcome/welcome_guide_page.dart';

const _authPaths = {
  '/login',
  '/signup',
  '/forgot-password',
  '/reset-password',
  '/verify-signup',
};

/// Instant page swap — no cross-fade/slide. Used for the bottom-tab
/// destinations so switching tabs never shows the old and new screen
/// overlapping mid-transition; the old one is simply gone and the new one is
/// there, like a native bottom-nav tab switch.
class _NoTransitionPage<T> extends CustomTransitionPage<T> {
  _NoTransitionPage({required super.child, super.key})
      : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, __, ___, child) => child,
        );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.listen(firstRunProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final firstRun = ref.read(firstRunProvider);
      final path = state.uri.path;
      final isAuthPath = _authPaths.contains(path);

      if (!auth.isHydrated || !firstRun.loaded) {
        return path == '/splash' ? null : '/splash';
      }

      // ── One-time feature tour — shown on first launch, BEFORE login/signup,
      // driven purely by the local device flag (not auth state). ──
      if (!firstRun.welcomeSeen) {
        return path == '/welcome' ? null : '/welcome';
      }
      if (path == '/welcome') {
        return auth.isAuthenticated ? '/dashboard' : '/login';
      }

      if (path == '/splash') return auth.isAuthenticated ? '/dashboard' : '/login';

      if (!auth.isAuthenticated) return isAuthPath ? null : '/login';

      // Authenticated from here.
      if (isAuthPath) return '/dashboard';
      final onboarded = auth.user?.onboardingCompleted ?? false;
      if (!onboarded && path != '/onboarding' && path != '/emergency') return '/onboarding';
      // Completing onboarding lands new users on the profile to fill health
      // info; this only fires on that one transition (returning users never
      // navigate to /onboarding).
      if (onboarded && path == '/onboarding') return '/profile?setup=1';
      if (path == '/') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const BootSplash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/verify-signup',
        builder: (_, state) =>
            VerifySignupPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeGuidePage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
      GoRoute(
        path: '/nova',
        builder: (_, state) => NovaChatPage(
          specialitySlug: state.uri.queryParameters['speciality'],
          conversationId: state.uri.queryParameters['conversation'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, __) => _NoTransitionPage(child: const DashboardPage()),
          ),
          GoRoute(
            path: '/specialities',
            pageBuilder: (_, __) => _NoTransitionPage(child: const SpecialitiesPage()),
          ),
          GoRoute(
            path: '/specialities/:slug',
            builder: (_, state) => SpecialityDetailPage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (_, __) => _NoTransitionPage(child: const HistoryPage()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, __) => _NoTransitionPage(child: const ReportsPage()),
          ),
          GoRoute(
            path: '/reports/:id',
            builder: (_, state) => ReportDetailPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => _NoTransitionPage(
              child: ProfilePage(setup: state.uri.queryParameters['setup'] == '1'),
            ),
          ),
          GoRoute(path: '/emergency', builder: (_, __) => const EmergencyPage()),
        ],
      ),
    ],
  );
});
