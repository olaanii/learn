import 'package:diaspora_equb_frontend/services/wallet_service.dart';

/// Shared FakeWalletService for all provider tests.
class FakeWalletService extends WalletService {
  String? fakeWalletAddress;
  String? fakeSignature = '0xFakeSignature';
  String? fakeTxHash = '0xFakeTxHash';
  bool connectShouldFail = false;
  bool signShouldFail = false;

  @override
  bool get isConnected => fakeWalletAddress != null;

  @override
  String? get walletAddress => fakeWalletAddress;

  @override
  String? get errorMessage => connectShouldFail ? 'Connection failed' : null;

  @override
  Future<void> init() async {}

  @override
  Future<String?> connect({WalletConnectionMethod? method}) async {
    if (connectShouldFail) return null;
    fakeWalletAddress = '0xFakeWallet';
    notifyListeners();
    return fakeWalletAddress;
  }

  @override
  Future<String?> personalSign(String message) async {
    if (signShouldFail) return null;
    return fakeSignature;
  }

  @override
  Future<String?> signAndSendTransaction(
      Map<String, dynamic> unsignedTx) async {
    if (signShouldFail) return null;
    return fakeTxHash;
  }

  @override
  Future<void> disconnect() async {
    fakeWalletAddress = null;
    notifyListeners();
  }
}
