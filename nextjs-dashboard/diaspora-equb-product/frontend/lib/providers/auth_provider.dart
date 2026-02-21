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
  /// Still connects MetaMask to use the real wallet address for balance queries.
  Future<void> skipFaydaForTesting() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try to connect MetaMask so we use the real wallet address
      final connectedAddress = await _walletService.connect();
      final address =
          connectedAddress ?? '0x0000000000000000000000000000000000DE1057';

      final response = await _api.devLogin(walletAddress: address);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = address;
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

  /// Valid EVM address regex (0x + 40 hex chars).
  static final _evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');

  static const _devTestAddress = '0x0000000000000000000000000000000000DE1057';

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

      // If the stored address is the dev placeholder, try to reconnect
      // the real wallet so balances reflect the user's actual address.
      if (wallet == null ||
          wallet.isEmpty ||
          wallet.toLowerCase() == _devTestAddress.toLowerCase()) {
        final realAddress = await _walletService.connect();
        if (realAddress != null) {
          _walletAddress = realAddress;
          // Re-issue JWT with real address
          try {
            final response = await _api.devLogin(walletAddress: realAddress);
            await _api.saveToken(response['accessToken']);
          } catch (_) {
            // Keep going with old JWT — at least balances will be correct
          }
        }
      }

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
