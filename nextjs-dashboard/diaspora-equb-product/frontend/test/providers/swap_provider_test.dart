import 'package:diaspora_equb_frontend/providers/swap_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_wallet_service.dart';

void main() {
  group('SwapProvider', () {
    late FakeApiClient api;
    late FakeWalletService wallet;
    late SwapProvider provider;

    setUp(() {
      api = FakeApiClient();
      wallet = FakeWalletService()..fakeWalletAddress = '0xFakeWallet';
      provider = SwapProvider(api, wallet);
    });

    test('loadStatus hydrates router and supported tokens', () async {
      await provider.loadStatus();

      expect(provider.routerConfigured, isTrue);
      expect(provider.routerAddress, isNotNull);
      expect(provider.nativeSymbol, 'tCTC');
      expect(provider.supportedTokenSymbols, containsAll(['USDC', 'USDT']));
    });

    test('fetchQuote marks approval required when allowance is insufficient',
        () async {
      await provider.loadStatus();
      provider.setFromToken('USDC');
      provider.setToToken('tCTC');

      api.tokenAllowanceResponse = {
        ...api.tokenAllowanceResponse,
        'allowanceRaw': '0',
        'hasSufficientAllowance': false,
      };

      await provider.fetchQuote('10', walletAddress: '0xFakeWallet');

      expect(provider.quote, '9.9');
      expect(provider.requiresApproval, isTrue);
      expect(api.tokenAllowanceCallCount, 1);
    });

    test('executeSwap skips approval when allowance is already sufficient',
        () async {
      await provider.loadStatus();
      provider.setFromToken('USDC');
      provider.setToToken('tCTC');

      api.tokenAllowanceResponse = {
        ...api.tokenAllowanceResponse,
        'allowanceRaw': '10000000',
        'hasSufficientAllowance': true,
      };

      final txHash = await provider.executeSwap(
        amountText: '10',
        walletAddress: '0xFakeWallet',
      );

      expect(txHash, '0xFakeTxHash');
      expect(api.buildSwapApprovalCallCount, 0);
      expect(api.buildSwapTxCallCount, 1);
    });

    test('executeSwap performs approval before swap when required', () async {
      await provider.loadStatus();
      provider.setFromToken('USDC');
      provider.setToToken('tCTC');

      api.tokenAllowanceResponse = {
        ...api.tokenAllowanceResponse,
        'allowanceRaw': '0',
        'hasSufficientAllowance': false,
      };

      final txHash = await provider.executeSwap(
        amountText: '10',
        walletAddress: '0xFakeWallet',
      );

      expect(txHash, '0xFakeTxHash');
      expect(provider.lastApprovalTxHash, '0xFakeTxHash');
      expect(api.buildSwapApprovalCallCount, 1);
      expect(api.buildSwapTxCallCount, 1);
    });
  });
}
