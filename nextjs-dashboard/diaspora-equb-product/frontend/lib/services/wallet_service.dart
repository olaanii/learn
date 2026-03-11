import 'dart:convert';

import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb;
import 'package:privy_flutter/privy_flutter.dart';
import '../config/app_config.dart';
import 'firebase_auth_service.dart';

enum WalletConnectionMethod {
  auto,
  embedded,
  injected,
  walletConnect,
  metaMaskApp,
  okxApp,
  binanceApp,
}

/// Service that manages Privy custom-auth login and embedded wallet signing.
class WalletService extends ChangeNotifier {
  WalletService([FirebaseAuthService? firebaseAuthService])
      : _firebaseAuthService = firebaseAuthService ?? FirebaseAuthService();

  final FirebaseAuthService _firebaseAuthService;

  Privy? _privy;
  PrivyUser? _privyUser;
  EmbeddedEthereumWallet? _embeddedWallet;
  String? _walletAddress;
  bool _isConnecting = false;
  String? _errorMessage;
  int _chainId = AppConfig.chainId;

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get hasPrivyConfiguration =>
      AppConfig.privyAppId.trim().isNotEmpty &&
      AppConfig.privyAppClientId.trim().isNotEmpty;
  bool get isConnected => _walletAddress != null && _embeddedWallet != null;
  bool get canUseInjectedProvider => false;
  bool get hasWalletConnectProjectId => false;
  String? get walletAddress => _walletAddress;
  String? get pairingUri => null;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  Object? get session => null;
  int get chainId => _chainId;

  Future<void> init() async {
    if (_privy != null || !isSupportedPlatform) {
      return;
    }

    if (!hasPrivyConfiguration) {
      debugPrint(
        '[WalletService] Privy is not configured. '
        'Set PRIVY_APP_ID and PRIVY_APP_CLIENT_ID via --dart-define.',
      );
      return;
    }

    _privy = Privy.init(
      config: PrivyConfig(
        appId: AppConfig.privyAppId,
        appClientId: AppConfig.privyAppClientId,
        logLevel: kDebugMode ? PrivyLogLevel.debug : PrivyLogLevel.none,
        customAuthConfig: LoginWithCustomAuthConfig(
          tokenProvider: () async {
            if (!_firebaseAuthService.isConfigured ||
                _firebaseAuthService.currentUser == null) {
              return null;
            }

            try {
              return await _firebaseAuthService.getIdToken(forceRefresh: true);
            } catch (_) {
              return null;
            }
          },
        ),
      ),
    );

    await _hydrateExistingSession();
  }

  Future<void> setChainId(
    int chainId, {
    bool switchConnectedWallet = true,
  }) async {
    if (_chainId == chainId) return;

    _chainId = chainId;
    if (_walletAddress != null) {
      notifyListeners();
    }

    if (!isConnected || _embeddedWallet == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> connect({
    WalletConnectionMethod method = WalletConnectionMethod.auto,
  }) async {
    if (!isSupportedPlatform) {
      _setError(
        'Privy embedded wallets are only available on Android and iOS. '
        'Use manual wallet binding on web or desktop.',
      );
      return null;
    }

    if (!hasPrivyConfiguration) {
      _setError(
        'Privy is not configured. Add PRIVY_APP_ID and PRIVY_APP_CLIENT_ID '
        'to this build.',
      );
      return null;
    }

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wallet = await _ensureEmbeddedWallet();
      _isConnecting = false;
      notifyListeners();
      return wallet?.address;
    } catch (e) {
      _isConnecting = false;
      _setError('Wallet connection failed: $e');
      return null;
    }
  }

  Future<void> _hydrateExistingSession() async {
    final privy = _privy;
    if (privy == null) {
      return;
    }

    final authState = await privy.getAuthState();
    final user = authState.user;
    if (user == null) {
      return;
    }

    _privyUser = user;
    await _refreshUser(ignoreFailures: true);
    _selectEmbeddedWallet();
  }

  Future<EmbeddedEthereumWallet?> _ensureEmbeddedWallet() async {
    await init();

    final user = await _ensurePrivyUser();
    if (user == null) {
      return null;
    }

    await _refreshUser(ignoreFailures: true);
    final existingWallet = _selectEmbeddedWallet();
    if (existingWallet != null) {
      return existingWallet;
    }

    final createResult = await user.createEthereumWallet();
    switch (createResult) {
      case Success<EmbeddedEthereumWallet>(:final value):
        _embeddedWallet = value;
        _walletAddress = value.address;
        _errorMessage = null;
        notifyListeners();
        return value;
      case Failure<EmbeddedEthereumWallet>(:final error):
        _setError('Privy wallet creation failed: ${error.message}');
        return null;
    }
  }

  Future<PrivyUser?> _ensurePrivyUser() async {
    final privy = _privy;
    if (privy == null) {
      _setError('Privy is not initialized for this device.');
      return null;
    }

    final authState = await privy.getAuthState();
    if (authState.user != null) {
      _privyUser = authState.user;
      return _privyUser;
    }

    if (_firebaseAuthService.currentUser == null) {
      _setError(
        'Sign in to your Diaspora Equb account before creating a Privy wallet.',
      );
      return null;
    }

    final loginResult = await privy.customAuth.loginWithCustomAccessToken();
    switch (loginResult) {
      case Success<PrivyUser>(:final value):
        _privyUser = value;
        _errorMessage = null;
        notifyListeners();
        return value;
      case Failure<PrivyUser>(:final error):
        _setError(
          'Privy sign-in failed. Verify the dashboard custom auth setup '
          'matches your Firebase tokens: ${error.message}',
        );
        return null;
    }
  }

  Future<void> _refreshUser({bool ignoreFailures = false}) async {
    final user = _privyUser;
    if (user == null) {
      return;
    }

    final refreshResult = await user.refresh();
    switch (refreshResult) {
      case Success<void>():
        return;
      case Failure<void>(:final error):
        if (!ignoreFailures) {
          _setError('Failed to refresh Privy wallet state: ${error.message}');
        }
    }
  }

  EmbeddedEthereumWallet? _selectEmbeddedWallet() {
    final wallets = _privyUser?.embeddedEthereumWallets;
    if (wallets == null || wallets.isEmpty) {
      _embeddedWallet = null;
      _walletAddress = null;
      notifyListeners();
      return null;
    }

    _embeddedWallet = wallets.first;
    _walletAddress = _embeddedWallet!.address;
    _errorMessage = null;
    notifyListeners();
    return _embeddedWallet;
  }

  Future<String?> signAndSendTransaction(
    Map<String, dynamic> unsignedTx,
  ) async {
    final wallet = await _ensureEmbeddedWallet();
    if (wallet == null || _walletAddress == null) {
      _setError('Wallet not connected');
      return null;
    }

    final chainIdRaw = unsignedTx['chainId'];
    final chainIdHex = chainIdRaw != null
        ? _toHex(
            chainIdRaw is int ? chainIdRaw.toString() : chainIdRaw.toString(),
          )
        : _toHex(_chainId.toString());

    final valueHex = _toHex(unsignedTx['value'] ?? '0');
    final gasHex = _toHex(unsignedTx['estimatedGas'] ?? '300000');
    final txParams = {
      'from': _walletAddress,
      'to': unsignedTx['to'],
      'data': unsignedTx['data'],
      'value': valueHex,
      'gas': gasHex,
      'chainId': chainIdHex,
    };

    final request = EthereumRpcRequest.ethSendTransaction(
      jsonEncode(txParams),
    );
    final result = await wallet.provider.request(request);

    switch (result) {
      case Success<EthereumRpcResponse>(:final value):
        _errorMessage = null;
      notifyListeners();
        return value.data;
      case Failure<EthereumRpcResponse>(:final error):
        _setError(_formatTxFailureMessage(error));
        return null;
    }
  }

  Future<String?> personalSign(String message) async {
    final wallet = await _ensureEmbeddedWallet();
    if (wallet == null || _walletAddress == null) {
      _setError('Wallet not connected');
      return null;
    }

    final hexMessage =
        '0x${message.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';
    final request = EthereumRpcRequest.personalSign(hexMessage, _walletAddress!);
    final result = await wallet.provider.request(request);

    switch (result) {
      case Success<EthereumRpcResponse>(:final value):
        _errorMessage = null;
        notifyListeners();
        return value.data;
      case Failure<EthereumRpcResponse>(:final error):
        _setError('Signing failed: ${error.message}');
        return null;
    }
  }

  static String _formatTxFailureMessage(Object e) {
    var s = e.toString();
    if (s.contains('[object Object]')) {
      s = s.replaceAll('[object Object]', '').trim();
      if (s.isEmpty || s == 'Exception:') {
        s = 'Transaction rejected or failed in wallet';
      }
    }
    final base = 'Transaction failed: $s';
    if (RegExp(r'0x[0-9a-fA-F]{8}').hasMatch(s)) {
      return '$base\n(Contract reverted. For token pools, approve the token first; or check Blockscout for the revert reason.)';
    }
    return base;
  }

  Future<void> disconnect() async {
    final privy = _privy;
    if (privy != null) {
      try {
        await privy.logout();
      } catch (_) {
        // Ignore logout failures and clear local state regardless.
      }
    }

    _embeddedWallet = null;
    _privyUser = null;
    _walletAddress = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  String _toHex(String decimalOrHex) {
    if (decimalOrHex.startsWith('0x')) return decimalOrHex;

    final intValue = BigInt.tryParse(decimalOrHex);
    if (intValue != null) {
      return '0x${intValue.toRadixString(16)}';
    }

    final looksDecimal = decimalOrHex.contains('.');
    if (looksDecimal) {
      try {
        final wei = EtherAmountEx.parseUnits(decimalOrHex, 18);
        return '0x${wei.toRadixString(16)}';
      } catch (_) {
        // Fall through to zero for malformed values.
      }
    }

    final value = BigInt.zero;
    return '0x${value.toRadixString(16)}';
  }
}

class EtherAmountEx {
  static BigInt parseUnits(String value, int decimals) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return BigInt.zero;

    final negative = trimmed.startsWith('-');
    final normalized = negative ? trimmed.substring(1) : trimmed;
    final parts = normalized.split('.');
    final whole = parts[0].isEmpty ? '0' : parts[0];
    final fractionRaw = parts.length > 1 ? parts[1] : '';

    final fraction = fractionRaw.length > decimals
        ? fractionRaw.substring(0, decimals)
        : fractionRaw.padRight(decimals, '0');

    final combined = '$whole$fraction';
    final parsed = BigInt.tryParse(combined) ?? BigInt.zero;
    return negative ? -parsed : parsed;
  }
}
