import 'package:diaspora_equb_frontend/providers/auth_provider.dart';
import 'package:diaspora_equb_frontend/providers/swap_provider.dart';
import 'package:diaspora_equb_frontend/providers/wallet_provider.dart';
import 'package:diaspora_equb_frontend/screens/swap_screen.dart';
import 'package:diaspora_equb_frontend/services/firebase_auth_service.dart';
import 'package:diaspora_equb_frontend/services/profile_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_wallet_service.dart';

class _FakeFirebaseAuthService extends FirebaseAuthService {
  @override
  bool get isConfigured => false;

  @override
  Future<void> signOut() async {}
}

class _FakeProfilePreferencesService extends ProfilePreferencesService {
  StoredProfilePreferences stored = const StoredProfilePreferences();

  @override
  Future<StoredProfilePreferences> load() async => stored;

  @override
  Future<StoredProfilePreferences> save(
    StoredProfilePreferences preferences,
  ) async {
    stored = preferences;
    return stored;
  }
}

void main() {
  group('SwapScreen', () {
    late FakeApiClient api;
    late FakeWalletService walletService;
    late WalletProvider walletProvider;
    late SwapProvider swapProvider;
    late AuthProvider authProvider;

    setUp(() async {
      api = FakeApiClient();
      walletService = FakeWalletService()..fakeWalletAddress = '0xFakeWallet';
      walletProvider = WalletProvider(api, walletService);
      swapProvider = SwapProvider(api, walletService);
      authProvider = AuthProvider(
        api,
        walletService,
        _FakeFirebaseAuthService(),
        _FakeProfilePreferencesService(),
      );
      await authProvider.skipFaydaForTesting();
    });

    Future<void> pumpSwapScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SwapProvider>.value(value: swapProvider),
            ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SwapScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows Approve & Swap when token allowance is insufficient',
        (tester) async {
      api.tokenAllowanceResponse = {
        ...api.tokenAllowanceResponse,
        'allowanceRaw': '0',
        'hasSufficientAllowance': false,
      };

      await swapProvider.loadStatus();
      swapProvider.setFromToken('USDC');
      swapProvider.setToToken('tCTC');

      await pumpSwapScreen(tester);
      await swapProvider.fetchQuote(
        '10',
        walletAddress: authProvider.walletAddress,
      );
      await tester.pump();

      expect(find.text('Approve & Swap'), findsOneWidget);
    });

    testWidgets('shows readiness messaging when router is not configured',
        (tester) async {
      api.swapStatusResponse = {
        ...api.swapStatusResponse,
        'routerConfigured': false,
      };

      await pumpSwapScreen(tester);

      expect(
        find.text('Swap router is not configured for this environment yet.'),
        findsOneWidget,
      );
    });
  });
}
