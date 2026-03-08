import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'services/api_client.dart';
import 'services/app_snackbar_service.dart';
import 'services/device_identity_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/profile_preferences_service.dart';
import 'services/wallet_service.dart';
import 'providers/auth_provider.dart';
import 'providers/pool_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/collateral_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/equb_insights_provider.dart';
import 'providers/governance_provider.dart';
import 'providers/network_provider.dart';
import 'providers/swap_provider.dart';
import 'providers/theme_provider.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final deviceIdentityService = DeviceIdentityService();
  final firebaseAuthService = FirebaseAuthService();
  final profilePreferencesService = ProfilePreferencesService();
  final networkProvider = NetworkProvider();
  final walletService = WalletService();

  await firebaseAuthService.initialize();
  await networkProvider.loadSavedNetwork();
  await walletService.setChainId(
    networkProvider.chainId,
    switchConnectedWallet: false,
  );

  unawaited(walletService.init());

  final authProvider = AuthProvider(
    apiClient,
    walletService,
    firebaseAuthService,
    profilePreferencesService,
  );
  final poolProvider = PoolProvider(apiClient, walletService);
  final creditProvider = CreditProvider(apiClient);
  final walletProvider = WalletProvider(apiClient, walletService);
  final collateralProvider = CollateralProvider(apiClient, walletService);
  final notificationProvider = NotificationProvider(apiClient);
  final equbInsightsProvider = EqubInsightsProvider(apiClient);
  final governanceProvider = GovernanceProvider(apiClient, walletService);
  final swapProvider = SwapProvider(apiClient, walletService);
  final themeProvider = ThemeProvider();

  await Future.wait([
    authProvider.tryAutoLogin(),
  ]);

  networkProvider.addListener(() {
    unawaited(walletService.setChainId(networkProvider.chainId));
  });

  notificationProvider.handleAuthStateChanged(authProvider.isAuthenticated);

  var previousAuthState = authProvider.isAuthenticated;
  authProvider.addListener(() {
    final isAuthenticated = authProvider.isAuthenticated;
    if (isAuthenticated == previousAuthState) {
      return;
    }

    previousAuthState = isAuthenticated;
    notificationProvider.handleAuthStateChanged(isAuthenticated);
    if (!isAuthenticated) {
      equbInsightsProvider.clearWalletContext();
    }
  });

  final router = createRouter(authProvider);

  final app = MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: apiClient),
      Provider<DeviceIdentityService>.value(value: deviceIdentityService),
      Provider<FirebaseAuthService>.value(value: firebaseAuthService),
      Provider<ProfilePreferencesService>.value(
        value: profilePreferencesService,
      ),
      ChangeNotifierProvider.value(value: walletService),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: poolProvider),
      ChangeNotifierProvider.value(value: creditProvider),
      ChangeNotifierProvider.value(value: walletProvider),
      ChangeNotifierProvider.value(value: collateralProvider),
      ChangeNotifierProvider.value(value: notificationProvider),
      ChangeNotifierProvider.value(value: equbInsightsProvider),
      ChangeNotifierProvider.value(value: governanceProvider),
      ChangeNotifierProvider.value(value: networkProvider),
      ChangeNotifierProvider.value(value: swapProvider),
      ChangeNotifierProvider.value(value: themeProvider),
    ],
    child: DiasporaEqubApp(router: router),
  );

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = const String.fromEnvironment('NODE_ENV',
            defaultValue: 'development');
      },
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}

class DiasporaEqubApp extends StatefulWidget {
  final GoRouter router;

  const DiasporaEqubApp({super.key, required this.router});

  @override
  State<DiasporaEqubApp> createState() => _DiasporaEqubAppState();
}

class _DiasporaEqubAppState extends State<DiasporaEqubApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<NotificationProvider>().handleAppLifecycleChanged(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: 'Diaspora Equb',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: AppSnackbarService.instance.messengerKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: widget.router,
        );
      },
    );
  }
}
