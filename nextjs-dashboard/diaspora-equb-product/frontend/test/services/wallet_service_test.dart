import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_wallet_service.dart';

void main() {
  group('WalletService', () {
    late FakeWalletService service;

    setUp(() {
      service = FakeWalletService();
    });

    group('connect', () {
      test('returns wallet address on success', () async {
        final address = await service.connect();
        expect(address, '0xFakeWallet');
        expect(service.isConnected, isTrue);
        expect(service.walletAddress, '0xFakeWallet');
      });

      test('returns null on failure', () async {
        service.connectShouldFail = true;
        final address = await service.connect();
        expect(address, isNull);
        expect(service.isConnected, isFalse);
      });
    });

    group('disconnect', () {
      test('clears wallet address', () async {
        await service.connect();
        expect(service.isConnected, isTrue);

        await service.disconnect();
        expect(service.isConnected, isFalse);
        expect(service.walletAddress, isNull);
      });
    });

    group('personalSign', () {
      test('returns signature on success', () async {
        final sig = await service.personalSign('Sign this message');
        expect(sig, '0xFakeSignature');
      });

      test('returns null when user rejects', () async {
        service.signShouldFail = true;
        final sig = await service.personalSign('Sign this message');
        expect(sig, isNull);
      });
    });

    group('signAndSendTransaction', () {
      test('returns tx hash on success', () async {
        final txHash = await service.signAndSendTransaction({
          'to': '0xContract',
          'data': '0x1234',
          'value': '0',
          'chainId': 102031,
        });
        expect(txHash, '0xFakeTxHash');
      });

      test('returns null when user rejects', () async {
        service.signShouldFail = true;
        final txHash = await service.signAndSendTransaction({
          'to': '0xContract',
          'data': '0x1234',
          'value': '0',
          'chainId': 102031,
        });
        expect(txHash, isNull);
      });
    });

    group('state transitions', () {
      test('connect then disconnect cycle', () async {
        expect(service.isConnected, isFalse);

        await service.connect();
        expect(service.isConnected, isTrue);

        await service.disconnect();
        expect(service.isConnected, isFalse);

        await service.connect();
        expect(service.isConnected, isTrue);
      });

      test('notifies listeners on connect', () async {
        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.connect();
        expect(notifyCount, greaterThan(0));
      });

      test('notifies listeners on disconnect', () async {
        await service.connect();

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.disconnect();
        expect(notifyCount, greaterThan(0));
      });
    });
  });
}
