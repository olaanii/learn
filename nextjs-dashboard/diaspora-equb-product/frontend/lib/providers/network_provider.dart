import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class NetworkProvider extends ChangeNotifier {
  static const _storageKey = 'selected_network';
  static const _storage = FlutterSecureStorage();

  bool _isTestnet;

  NetworkProvider() : _isTestnet = !AppConfig.isMainnet;

  bool get isTestnet => _isTestnet;
  bool get isMainnet => !_isTestnet;

  int get chainId => _isTestnet ? 102031 : 102030;

  String get nativeSymbol => _isTestnet ? 'tCTC' : 'CTC';

  String get rpcUrl => _isTestnet
      ? 'https://rpc.cc3-testnet.creditcoin.network'
      : 'https://mainnet3.creditcoin.network';

  String get explorerUrl => _isTestnet
      ? 'https://creditcoin-testnet.blockscout.com'
      : 'https://creditcoin.blockscout.com';

  String get networkName =>
      _isTestnet ? 'Creditcoin Testnet' : 'Creditcoin Mainnet';

  String get shortNetworkName => _isTestnet ? 'Testnet' : 'Mainnet';

  Future<void> loadSavedNetwork() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        _isTestnet = saved == 'testnet';
        notifyListeners();
      }
    } catch (_) {
      // Use default from AppConfig
    }
  }

  Future<void> toggleNetwork() async {
    _isTestnet = !_isTestnet;
    notifyListeners();
    try {
      await _storage.write(
        key: _storageKey,
        value: _isTestnet ? 'testnet' : 'mainnet',
      );
    } catch (_) {
      // Non-critical — preference just won't persist
    }
  }

  Future<void> setTestnet(bool testnet) async {
    if (_isTestnet == testnet) return;
    _isTestnet = testnet;
    notifyListeners();
    try {
      await _storage.write(
        key: _storageKey,
        value: _isTestnet ? 'testnet' : 'mainnet',
      );
    } catch (_) {}
  }
}
