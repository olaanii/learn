import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../config/app_config.dart';

enum AuthStatus { unauthenticated, loading, authenticated, walletBound }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _identityHash;
  String? _walletAddress;
  String? _errorMessage;

  AuthProvider(this._api);

  AuthStatus get status => _status;
  String? get identityHash => _identityHash;
  String? get walletAddress => _walletAddress;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.walletBound;

  Future<void> verifyFayda(String token) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.verifyFayda(token);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];

      if (response['walletBindingStatus'] == 'bound') {
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
  /// Calls the backend dev-login endpoint to get a real JWT, then jumps to walletBound.
  Future<void> skipFaydaForTesting() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.devLogin();
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = response['walletAddress'] ??
          '0x0000000000000000000000000000000000DE1057';
      _status = AuthStatus.walletBound;
    } catch (e) {
      // Fallback: set mock data without JWT (endpoints will 401)
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

  Future<void> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token == null) return;

    try {
      // Decode the JWT payload to extract identity + wallet
      final parts = token.split('.');
      if (parts.length != 3) throw FormatException('Invalid JWT');

      final payload = parts[1];
      // base64Url needs padding normalization
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      final wallet = data['walletAddress'] as String?;
      final identity = data['sub'] as String?;

      // If the stored JWT has an invalid wallet address, clear it and force re-login
      if (wallet != null && !_evmRegex.hasMatch(wallet)) {
        await _api.clearToken();
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _identityHash = identity;
      _walletAddress = wallet;

      if (wallet != null && wallet.isNotEmpty) {
        _status = AuthStatus.walletBound;
      } else {
        _status = AuthStatus.authenticated;
      }
    } catch (_) {
      // Token is malformed or expired — clear and force fresh login
      await _api.clearToken();
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    _status = AuthStatus.unauthenticated;
    _identityHash = null;
    _walletAddress = null;
    notifyListeners();
  }
}
