import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'services/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/pool_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/collateral_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authProvider = AuthProvider(apiClient);
  final poolProvider = PoolProvider(apiClient);
  final creditProvider = CreditProvider(apiClient);
  final walletProvider = WalletProvider(apiClient);
  final collateralProvider = CollateralProvider(apiClient);
  final router = createRouter(authProvider);

  // Kick off auto-login before the first frame
  authProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: poolProvider),
        ChangeNotifierProvider.value(value: creditProvider),
        ChangeNotifierProvider.value(value: walletProvider),
        ChangeNotifierProvider.value(value: collateralProvider),
      ],
      child: DiasporaEqubApp(router: router),
    ),
  );
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
