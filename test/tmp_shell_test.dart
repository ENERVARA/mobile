import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enervara/core/theme/app_theme.dart';
import 'package:enervara/data/models/user.dart';
import 'package:enervara/router/app_router.dart';
import 'package:enervara/ui/screens/dashboard/dashboard_page.dart';
import 'package:enervara/ui/widgets/common.dart';
import 'package:enervara/state/auth_provider.dart';
import 'package:enervara/state/boot_gate_provider.dart';
import 'package:enervara/state/first_run_provider.dart';
import 'package:enervara/state/nova_ui_provider.dart';

class _Auth extends AuthController {
  _Auth(super.ref) {
    state = const AuthState(
      isAuthenticated: true,
      isHydrated: true,
      user: User(
        id: '1',
        email: 'a@b.c',
        firstName: 'Test',
        lastName: 'User',
        onboardingCompleted: true,
        heightCm: 170,
        weightKg: 70,
        createdAt: '2020-01-01T00:00:00Z',
      ),
    );
  }
}

class _Gate extends BootGateController {
  _Gate() {
    state = true;
  }
}

class _FirstRun extends FirstRunController {
  _FirstRun() {
    state = const FirstRunState(loaded: true, welcomeSeen: true);
  }
}

void main() {
  testWidgets('shell renders after login', (tester) async {
    SharedPreferences.setMockInitialValues({'enervara_welcome_seen': true});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    final errors = <Object>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth(ref)),
          bootGateProvider.overrideWith((ref) => _Gate()),
          firstRunProvider.overrideWith((ref) => _FirstRun()),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);
    Future<void> visit(String label, Future<void> Function() act) async {
      errors.clear();
      await act();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      final real = errors.where((e) => !e.toString().contains('overflowed')).toList();
      // ignore: avoid_print
      print('VISIT $label -> ${real.length} errors ${real.isEmpty ? '' : real.first.toString().replaceAll(RegExp(r'\s+'), ' ')}');
    }

    for (final path in (const String.fromEnvironment('ROUTES', defaultValue: '/care')).split(',')) {
      await visit(path, () async => router.go(path));
    }
    await visit('nova-open', () async => container.read(novaUiProvider.notifier).personalize('cardiology'));
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((t) => t.isNotEmpty).take(14).toList();
    // ignore: avoid_print
    print('NOVA TEXTS: $texts');
  });
}
