import 'package:diaspora_equb_frontend/providers/pool_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_wallet_service.dart';

void main() {
  group('PoolProvider', () {
    late FakeApiClient api;
    late FakeWalletService wallet;
    late PoolProvider provider;

    setUp(() {
      api = FakeApiClient();
      wallet = FakeWalletService();
      provider = PoolProvider(api, wallet);
    });

    test('initial state', () {
      expect(provider.pools, isEmpty);
      expect(provider.selectedPool, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    group('loadPools', () {
      test('loads pools from API', () async {
        api.poolsList = [
          {'id': 'p1', 'tier': 0, 'status': 'active'},
          {'id': 'p2', 'tier': 1, 'status': 'active'},
        ];

        await provider.loadPools();

        expect(provider.pools.length, 2);
        expect(provider.pools[0]['id'], 'p1');
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
      });

      test('loads pools with tier filter', () async {
        api.poolsList = [
          {'id': 'p1', 'tier': 1, 'status': 'active'},
        ];

        await provider.loadPools(tier: 1);

        expect(provider.pools.length, 1);
      });

      test('sets error on API failure', () async {
        api.poolApiShouldThrow = true;

        await provider.loadPools();

        expect(provider.errorMessage, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });

    group('loadPool', () {
      test('loads single pool', () async {
        api.poolDetail = {
          'id': 'p1',
          'tier': 0,
          'status': 'active',
          'onChainPoolId': 1,
        };

        await provider.loadPool('p1');

        expect(provider.selectedPool, isNotNull);
        expect(provider.selectedPool!['id'], 'p1');
      });

      test('sets error on failure', () async {
        api.poolApiShouldThrow = true;

        await provider.loadPool('missing');

        expect(provider.errorMessage, isNotNull);
      });
    });

    group('buildAndSignCreatePool', () {
      test('builds TX, signs, and creates pool from TX', () async {
        wallet.fakeWalletAddress = '0xCreator';

        await provider.buildAndSignCreatePool(
          tier: 0,
          contributionAmount: '1000',
          maxMembers: 5,
          treasury: '0xTreasury',
        );

        expect(provider.lastTxHash, '0xFakeTxHash');
        expect(provider.errorMessage, isNull);
      });

      test('sets error if signing fails', () async {
        wallet.fakeWalletAddress = '0xCreator';
        wallet.signShouldFail = true;

        await provider.buildAndSignCreatePool(
          tier: 0,
          contributionAmount: '1000',
          maxMembers: 5,
          treasury: '0xTreasury',
        );

        expect(provider.errorMessage, isNotNull);
      });
    });

    group('buildAndSignJoinPool', () {
      test('builds and signs join TX', () async {
        wallet.fakeWalletAddress = '0xUser';

        await provider.buildAndSignJoinPool(1);

        expect(provider.lastTxHash, '0xFakeTxHash');
      });
    });

    group('buildAndSignContribute', () {
      test('builds and signs native contribution TX', () async {
        wallet.fakeWalletAddress = '0xUser';

        await provider.buildAndSignContribute(1, '1000000000000000000');

        expect(provider.lastTxHash, '0xFakeTxHash');
      });
    });

    group('closeActiveRound', () {
      test('calls API to close active round', () async {
        await provider.closeActiveRound('p1');
        expect(provider.errorMessage, isNull);
      });
    });

    group('pickWinnerForActiveRound', () {
      test('calls API to pick winner', () async {
        await provider.pickWinnerForActiveRound('p1');
        expect(provider.errorMessage, isNull);
      });
    });

    group('loading state', () {
      test('isLoading is true during loadPools', () async {
        bool wasLoading = false;
        provider.addListener(() {
          if (provider.isLoading) wasLoading = true;
        });

        await provider.loadPools();

        expect(wasLoading, isTrue);
        expect(provider.isLoading, isFalse);
      });
    });
  });
}
