import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'services/api_client.dart';
import 'services/wallet_service.dart';
import 'providers/auth_provider.dart';
import 'providers/pool_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/collateral_provider.dart';
import 'providers/notification_provider.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final walletService = WalletService();

  unawaited(walletService.init());

  final authProvider = AuthProvider(apiClient, walletService);
  final poolProvider = PoolProvider(apiClient, walletService);
  final creditProvider = CreditProvider(apiClient);
  final walletProvider = WalletProvider(apiClient, walletService);
  final collateralProvider = CollateralProvider(apiClient, walletService);
  final notificationProvider = NotificationProvider(apiClient);

  await authProvider.tryAutoLogin();

  if (authProvider.isAuthenticated) {
    unawaited(notificationProvider.refreshUnreadCount());
    notificationProvider.startPolling();
  }

  final router = createRouter(authProvider);

  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: walletService),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: poolProvider),
      ChangeNotifierProvider.value(value: creditProvider),
      ChangeNotifierProvider.value(value: walletProvider),
      ChangeNotifierProvider.value(value: collateralProvider),
      ChangeNotifierProvider.value(value: notificationProvider),
    ],
    child: DiasporaEqubApp(router: router),
  );

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment =
            const String.fromEnvironment('NODE_ENV', defaultValue: 'development');
      },
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}

class DiasporaEqubApp extends StatelessWidget {
  final GoRouter router;

  const DiasporaEqubApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Diaspora Equb',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
