import 'dart:convert';
import 'package:diaspora_equb_frontend/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_wallet_service.dart';

void main() {
  group('AuthProvider', () {
    late FakeApiClient api;
    late FakeWalletService wallet;
    late AuthProvider provider;

    setUp(() {
      api = FakeApiClient();
      wallet = FakeWalletService();
      provider = AuthProvider(api, wallet);
    });

    test('initial state is unauthenticated', () {
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.identityHash, isNull);
      expect(provider.walletAddress, isNull);
      expect(provider.isAuthenticated, isFalse);
    });

    group('verifyFayda', () {
      test('success sets authenticated and saves token', () async {
        await provider.verifyFayda('test-token');

        expect(provider.status, AuthStatus.authenticated);
        expect(provider.identityHash, '0xFakeHash');
        expect(provider.errorMessage, isNull);
        expect(api.savedToken, 'fake-jwt');
      });

      test('success with bound wallet sets walletBound', () async {
        api.verifyFaydaResponse = {
          'accessToken': 'jwt',
          'identityHash': '0xHash',
          'walletBindingStatus': 'bound',
          'walletAddress': '0xBoundWallet',
        };

        await provider.verifyFayda('token');

        expect(provider.status, AuthStatus.walletBound);
        expect(provider.walletAddress, '0xBoundWallet');
      });

      test('failure sets unauthenticated with error', () async {
        api.verifyFaydaShouldThrow = true;

        await provider.verifyFayda('bad-token');

        expect(provider.status, AuthStatus.unauthenticated);
        expect(provider.errorMessage, isNotNull);
      });
    });

    group('skipFaydaForTesting', () {
      test('sets walletBound with dev wallet', () async {
        await provider.skipFaydaForTesting();

        expect(provider.status, AuthStatus.walletBound);
        expect(provider.walletAddress,
            '0x0000000000000000000000000000000000DE1057');
        expect(provider.identityHash, '0xDevHash');
        expect(api.savedToken, 'fake-jwt-dev');
      });
    });

    group('loginWithWalletOnly', () {
      test('full SIWE flow succeeds', () async {
        await provider.loginWithWalletOnly();

        expect(provider.status, AuthStatus.walletBound);
        expect(provider.walletAddress, '0xFakeWallet');
        expect(provider.identityHash, '0xWalletHash');
        expect(api.savedToken, 'fake-jwt-wallet');
      });

      test('fails if wallet connection fails', () async {
        wallet.connectShouldFail = true;

        await provider.loginWithWalletOnly();

        expect(provider.status, AuthStatus.unauthenticated);
        expect(provider.errorMessage, isNotNull);
      });

      test('fails if signing is rejected', () async {
        wallet.signShouldFail = true;

        await provider.loginWithWalletOnly();

        expect(provider.status, AuthStatus.unauthenticated);
        expect(provider.errorMessage, isNotNull);
      });
    });

    group('logout', () {
      test('clears state and token', () async {
        await provider.skipFaydaForTesting();
        expect(provider.isAuthenticated, isTrue);

        await provider.logout();

        expect(provider.status, AuthStatus.unauthenticated);
        expect(provider.identityHash, isNull);
        expect(provider.walletAddress, isNull);
        expect(api.savedToken, isNull);
      });
    });

    group('tryAutoLogin', () {
      test('restores session from valid stored JWT', () async {
        final payload = base64Url.encode(utf8.encode(
          '{"sub":"0xIdentity","walletAddress":"0x0000000000000000000000000000000000DE1057"}',
        ));
        api.savedToken = 'header.$payload.signature';

        await provider.tryAutoLogin();

        expect(provider.status, AuthStatus.walletBound);
        expect(provider.walletAddress,
            '0x0000000000000000000000000000000000DE1057');
        expect(provider.identityHash, '0xIdentity');
      });

      test('clears invalid token and stays unauthenticated', () async {
        api.savedToken = 'not-a-jwt';

        await provider.tryAutoLogin();

        expect(provider.status, AuthStatus.unauthenticated);
        expect(api.savedToken, isNull);
      });

      test('does nothing when no token stored', () async {
        await provider.tryAutoLogin();

        expect(provider.status, AuthStatus.unauthenticated);
      });
    });
  });
}
