import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';
import '../config/app_config.dart';

enum AuthStatus { unauthenticated, loading, authenticated, walletBound }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  final WalletService _walletService;

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _identityHash;
  String? _walletAddress;
  String? _errorMessage;

  AuthProvider(this._api, this._walletService);

  AuthStatus get status => _status;
  String? get identityHash => _identityHash;
  String? get walletAddress => _walletAddress;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.walletBound;

  /// Access the wallet service for signing transactions.
  WalletService get walletService => _walletService;

  Future<void> verifyFayda(String token) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.verifyFayda(token);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];

      if (response['walletBindingStatus'] == 'bound') {
        _walletAddress = response['walletAddress'];
        _status = AuthStatus.walletBound;
      } else {
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      _errorMessage = 'Fayda verification failed. Please try again.';
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Bypass Fayda verification for testing.
  /// Dev login always uses the fixed dev wallet (DE1057) that joined the tier-0 pool,
  /// so pool membership and authorized API calls work. Does not use MetaMask for auth.
  Future<void> skipFaydaForTesting() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Always use DE1057 for dev so this identity is the one that joined the pool
      const devWallet = '0x0000000000000000000000000000000000DE1057';
      final response = await _api.devLogin(walletAddress: devWallet);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = devWallet;
      _status = AuthStatus.walletBound;
    } catch (e) {
      _identityHash =
          '0x0000000000000000000000000000000000000000000000000000000000de1057';
      _walletAddress = '0x0000000000000000000000000000000000DE1057';
      _status = AuthStatus.walletBound;
      _errorMessage = 'Dev login failed — API calls may not work: $e';
    }

    notifyListeners();
  }

  /// Whether the dev bypass button should be shown on the onboarding screen.
  bool get isDevBypassEnabled => AppConfig.devBypassFayda;

  /// Wallet-only login using Sign-In with Ethereum:
  /// 1. Connect MetaMask → get wallet address
  /// 2. Request a challenge from the backend
  /// 3. Sign the challenge with MetaMask
  /// 4. Backend verifies signature → issues JWT
  Future<void> loginWithWalletOnly() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Connect wallet
      final address = await _walletService.connect();
      if (address == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Wallet connection failed';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // 2. Request challenge
      final challenge = await _api.walletChallenge(address);
      final message = challenge['message'] as String;

      // 3. Sign the challenge with MetaMask
      final signature = await _walletService.personalSign(message);
      if (signature == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Message signing rejected';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // 4. Verify signature and get JWT
      final response = await _api.walletVerify(
        walletAddress: address,
        signature: signature,
        message: message,
      );

      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = address;
      _status = AuthStatus.walletBound;
    } catch (e) {
      _errorMessage = 'Wallet login failed: $e';
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Bind wallet using WalletConnect: connect the user's real wallet,
  /// then bind the wallet address to their identity on the backend.
  Future<void> connectAndBindWallet() async {
    if (_identityHash == null) return;

    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Connect via WalletConnect (user approves in their wallet app)
      final address = await _walletService.connect();
      if (address == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Wallet connection failed';
        notifyListeners();
        return;
      }

      // 2. Bind the wallet address from WalletConnect to the identity
      final response = await _api.bindWallet(_identityHash!, address);
      if (response['status'] == 'bound') {
        _walletAddress = address;
        _status = AuthStatus.walletBound;
      } else {
        _errorMessage = 'Wallet binding failed: ${response['status']}';
      }
    } catch (e) {
      _errorMessage = 'Failed to connect wallet: $e';
    }

    notifyListeners();
  }

  /// Legacy: bind wallet by pasting an address (kept for dev/test).
  Future<void> bindWallet(String walletAddress) async {
    if (_identityHash == null) return;

    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.bindWallet(_identityHash!, walletAddress);
      if (response['status'] == 'bound') {
        _walletAddress = walletAddress;
        _status = AuthStatus.walletBound;
      } else {
        _errorMessage = 'Wallet binding failed: ${response['status']}';
      }
    } catch (e) {
      _errorMessage = 'Failed to bind wallet. Please try again.';
    }

    notifyListeners();
  }

  /// Build and sign on-chain identity binding TX via IdentityRegistry.
  /// Required before joinPool succeeds on-chain.
  Future<String?> bindIdentityOnChain() async {
    if (_identityHash == null || _walletAddress == null) {
      _errorMessage =
          'Missing identity or wallet. Complete login and wallet binding first.';
      notifyListeners();
      return null;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildStoreOnChain(
        identityHash: _identityHash!,
        walletAddress: _walletAddress!,
      );

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ??
            'Identity binding transaction rejected';
        notifyListeners();
        return null;
      }

      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to bind identity on-chain: $e';
      notifyListeners();
      return null;
    }
  }

  /// Valid EVM address regex (0x + 40 hex chars).
  static final _evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');

  Future<void> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token == null) return;

    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException('Invalid JWT');

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      final wallet = data['walletAddress'] as String?;
      final identity = data['sub'] as String?;

      if (wallet != null && !_evmRegex.hasMatch(wallet)) {
        await _api.clearToken();
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _identityHash = identity;
      _walletAddress = wallet;

      // Keep DE1057 as-is on restore so pool membership and auth stay correct.
      // Do not replace with MetaMask address.

      if (_walletAddress != null && _walletAddress!.isNotEmpty) {
        _status = AuthStatus.walletBound;
      } else {
        _status = AuthStatus.authenticated;
      }
    } catch (_) {
      await _api.clearToken();
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    await _walletService.disconnect();
    _status = AuthStatus.unauthenticated;
    _identityHash = null;
    _walletAddress = null;
    notifyListeners();
  }
}
