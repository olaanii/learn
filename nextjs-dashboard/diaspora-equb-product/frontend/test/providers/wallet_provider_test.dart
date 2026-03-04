import 'package:diaspora_equb_frontend/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_wallet_service.dart';

void main() {
  group('WalletProvider', () {
    late FakeApiClient api;
    late FakeWalletService wallet;
    late WalletProvider provider;

    setUp(() {
      api = FakeApiClient();
      wallet = FakeWalletService();
      provider = WalletProvider(api, wallet);
    });

    test('initial state', () {
      expect(provider.token, 'USDC');
      expect(provider.balance, '0.00');
      expect(provider.isLoading, isFalse);
      expect(provider.transactions, isEmpty);
    });

    group('selectToken', () {
      test('switches selected token', () {
        provider.selectToken('USDT');
        expect(provider.token, 'USDT');
      });

      test('does nothing if same token', () {
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.selectToken('USDC');
        expect(notifyCount, 0);
      });
    });

    group('loadBalance', () {
      test('fetches balance for selected token', () async {
        api.balanceResponse = {
          'formatted': '250.50',
          'balance': '250500000',
          'decimals': 6,
          'symbol': 'USDC',
        };

        await provider.loadBalance('0xWallet', token: 'USDC');

        expect(provider.balance, '250.50');
        expect(provider.isLoading, isFalse);
      });

      test('sets error on failure', () async {
        api.walletApiShouldThrow = true;

        await provider.loadBalance('0xWallet');

        expect(provider.errorMessage, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });

    group('loadAllBalances', () {
      test('fetches balances for all tokens', () async {
        await provider.loadAllBalances('0xWallet');

        expect(provider.allBalances, isNotEmpty);
        expect(provider.isLoading, isFalse);
      });
    });

    group('loadTransactions', () {
      test('fetches transactions', () async {
        api.transactionsResponse = [
          {
            'txHash': '0x1',
            'type': 'sent',
            'token': 'USDC',
            'amount': '100',
          },
        ];

        await provider.loadTransactions('0xWallet');

        expect(provider.transactions.length, 1);
        expect(provider.transactions[0]['txHash'], '0x1');
      });
    });

    group('loadExchangeRates', () {
      test('fetches rates', () async {
        api.ratesResponse = {
          'rates': {'CTC': 0.5, 'USDC': 1.0, 'USDT': 1.0},
        };

        await provider.loadExchangeRates();

        expect(provider.rates, isNotEmpty);
      });
    });

    group('requestFaucet', () {
      test('calls faucet API and returns result', () async {
        final result = await provider.requestFaucet(
          walletAddress: '0xWallet',
          amount: 1000,
          token: 'USDC',
        );

        expect(result, isNotNull);
        expect(result!['txHash'], '0xFaucetTx');
        expect(provider.errorMessage, isNull);
      });
    });

    group('buildAndSignTransfer', () {
      test('builds and signs transfer TX', () async {
        wallet.fakeWalletAddress = '0xSender';

        await provider.buildAndSignTransfer(
          from: '0xSender',
          to: '0xRecipient',
          amount: '50',
          token: 'USDC',
        );

        expect(provider.lastTxHash, '0xFakeTxHash');
      });

      test('sets error if signing fails', () async {
        wallet.fakeWalletAddress = '0xSender';
        wallet.signShouldFail = true;

        await provider.buildAndSignTransfer(
          from: '0xSender',
          to: '0xRecipient',
          amount: '50',
          token: 'USDC',
        );

        expect(provider.errorMessage, isNotNull);
      });
    });

    group('buildAndSignWithdraw', () {
      test('builds and signs withdraw TX', () async {
        wallet.fakeWalletAddress = '0xUser';

        await provider.buildAndSignWithdraw(
          from: '0xUser',
          to: '0xExternal',
          amount: '100',
          token: 'USDC',
        );

        expect(provider.lastTxHash, '0xFakeTxHash');
      });
    });

    group('refreshAfterTx', () {
      test('reloads balances after transaction', () async {
        await provider.refreshAfterTx('0xWallet');

        expect(provider.isLoading, isFalse);
      });
    });

    group('error handling', () {
      test('API failure sets errorMessage and resets loading', () async {
        api.walletApiShouldThrow = true;

        await provider.loadBalance('0xWallet');

        expect(provider.errorMessage, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });
  });
}
