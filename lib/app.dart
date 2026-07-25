import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_messenger.dart';
import 'router/app_router.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';

class EnervaraApp extends ConsumerStatefulWidget {
  const EnervaraApp({super.key});

  @override
  ConsumerState<EnervaraApp> createState() => _EnervaraAppState();
}

class _EnervaraAppState extends ConsumerState<EnervaraApp> {
  @override
  void initState() {
    super.initState();
    // A 401 on an authenticated request → clear session, router redirects to /login.
    ApiClient.instance.onUnauthorized =
        () => ref.read(authProvider.notifier).forceLogout();
    // Tapping a push notification navigates via its `route` data field.
    PushNotificationService.instance.onNotificationTap =
        (route) => ref.read(routerProvider).go(route);
    // Hydrate persisted auth on boot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Enervara',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
