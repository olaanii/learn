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
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_config.dart';
import 'firebase_auth_service.dart';
import 'ethereum_provider_stub.dart'
    if (dart.library.js_interop) 'ethereum_provider_web.dart'
    as injected_provider;

enum WalletConnectionMethod {
  auto,
  embedded,
  injected,
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
  bool get canUseInjectedProvider =>
      kIsWeb && injected_provider.hasInjectedProvider;
  bool get isConnected => _walletAddress != null;
  String? get walletAddress => _walletAddress;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
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

    if (!switchConnectedWallet || !isConnected) {
      return;
    }

    if (kIsWeb && canUseInjectedProvider) {
      try {
        await injected_provider.switchInjectedChain(
          chainId: _chainId,
          chainName: AppConfig.networkName,
          rpcUrls: [AppConfig.rpcUrl],
          symbol: AppConfig.nativeSymbol,
          blockExplorerUrls: [AppConfig.explorerUrl],
        );
      } catch (e, st) {
        _setWalletError(
          operation: 'switch_chain',
          error: e,
          stackTrace: st,
          flow: 'injected_web',
        );
        return;
      }
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> connect({
    WalletConnectionMethod method = WalletConnectionMethod.auto,
  }) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        if (method == WalletConnectionMethod.embedded) {
          _setError(
            'Privy embedded wallets are only available on Android and iOS.',
          );
          return null;
        }

        final address = await injected_provider.connectViaInjectedProvider();
        if (address == null || address.trim().isEmpty) {
          _setError(
            'No injected web wallet found. Install/unlock a browser wallet or use manual wallet binding.',
          );
          return null;
        }

        _embeddedWallet = null;
        _walletAddress = address;
        _errorMessage = null;
        notifyListeners();
        return address;
      }

      if (!isSupportedPlatform) {
        _setError(
          'Wallet connection is unavailable on this platform. Use manual wallet binding.',
        );
        return null;
      }

      if (method == WalletConnectionMethod.injected) {
        _setError('Injected wallets are only supported on web.');
        return null;
      }

      if (!hasPrivyConfiguration) {
        _setError(
          'Privy is not configured. Add PRIVY_APP_ID and PRIVY_APP_CLIENT_ID to this build.',
        );
        return null;
      }

      final wallet = await _ensureEmbeddedWallet();
      return wallet?.address;
    } catch (e, st) {
      _setWalletError(
        operation: 'connect',
        error: e,
        stackTrace: st,
        flow: kIsWeb ? 'injected_web' : 'privy_embedded',
      );
      return null;
    } finally {
      _isConnecting = false;
      notifyListeners();
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
    try {
      if (kIsWeb) {
        final fromAddress = _walletAddress ?? await connect();
        if (fromAddress == null) {
          _setError('Wallet not connected');
          return null;
        }

        final txHash = await injected_provider.sendTransactionViaInjected(
          _buildTxParams(unsignedTx, fromAddress),
        );
        if (txHash == null || txHash.isEmpty) {
          _setError('Transaction was not submitted by the wallet.');
          return null;
        }

        _errorMessage = null;
        notifyListeners();
        return txHash;
      }

      final wallet = await _ensureEmbeddedWallet();
      if (wallet == null || _walletAddress == null) {
        _setError('Wallet not connected');
        return null;
      }

      final request = EthereumRpcRequest.ethSendTransaction(
        jsonEncode(_buildTxParams(unsignedTx, _walletAddress!)),
      );
      final result = await wallet.provider.request(request);

      switch (result) {
        case Success<EthereumRpcResponse>(:final value):
          _errorMessage = null;
          notifyListeners();
          return value.data;
        case Failure<EthereumRpcResponse>(:final error):
          _setWalletError(
            operation: 'send_transaction',
            error: error,
            flow: 'privy_embedded',
          );
          return null;
      }
    } catch (e, st) {
      _setWalletError(
        operation: 'send_transaction',
        error: e,
        stackTrace: st,
        flow: kIsWeb ? 'injected_web' : 'privy_embedded',
      );
      return null;
    }
  }

  Map<String, dynamic> _buildTxParams(
    Map<String, dynamic> unsignedTx,
    String from,
  ) {
    final chainIdRaw = unsignedTx['chainId'];
    final chainIdHex = chainIdRaw != null
        ? _toHex(
            chainIdRaw is int ? chainIdRaw.toString() : chainIdRaw.toString(),
          )
        : _toHex(_chainId.toString());

    final valueHex = _toHex(unsignedTx['value'] ?? '0');
    final gasHex = _toHex(unsignedTx['estimatedGas'] ?? '300000');

    return {
      'from': from,
      'to': unsignedTx['to'],
      'data': unsignedTx['data'],
      'value': valueHex,
      'gas': gasHex,
      'chainId': chainIdHex,
    };
  }

  Future<String?> personalSign(String message) async {
    try {
      if (kIsWeb) {
        final address = _walletAddress ?? await connect();
        if (address == null || address.isEmpty) {
          _setError('Wallet not connected');
          return null;
        }

        final signature =
            await injected_provider.personalSignViaInjected(message, address);
        if (signature == null || signature.isEmpty) {
          _setError('Signing request was rejected by the wallet.');
          return null;
        }

        _errorMessage = null;
        notifyListeners();
        return signature;
      }

      final wallet = await _ensureEmbeddedWallet();
      if (wallet == null || _walletAddress == null) {
        _setError('Wallet not connected');
        return null;
      }

      final hexMessage =
          '0x${message.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';
      final request =
          EthereumRpcRequest.personalSign(hexMessage, _walletAddress!);
      final result = await wallet.provider.request(request);

      switch (result) {
        case Success<EthereumRpcResponse>(:final value):
          _errorMessage = null;
          notifyListeners();
          return value.data;
        case Failure<EthereumRpcResponse>(:final error):
          _setWalletError(
            operation: 'personal_sign',
            error: error,
            flow: 'privy_embedded',
          );
          return null;
      }
    } catch (e, st) {
      _setWalletError(
        operation: 'personal_sign',
        error: e,
        stackTrace: st,
        flow: kIsWeb ? 'injected_web' : 'privy_embedded',
      );
      return null;
    }
  }

  String _normalizeWalletErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty || raw == '[object Object]') {
      return 'Unknown wallet error';
    }

    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }

    return raw;
  }

  String _classifyWalletError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('4001') ||
        lower.contains('user rejected') ||
        lower.contains('rejected') ||
        lower.contains('denied') ||
        lower.contains('cancelled')) {
      return 'rejected';
    }
    if (lower.contains('wallet is locked') ||
        lower.contains('unlock') ||
        lower.contains('authentication needed')) {
      return 'locked_wallet';
    }
    if (lower.contains('insufficient funds')) {
      return 'insufficient_funds';
    }
    if (lower.contains('execution reverted') ||
        lower.contains('revert') ||
        RegExp(r'0x[0-9a-fA-F]{8}').hasMatch(message)) {
      return 'revert';
    }
    return 'unknown';
  }

  String _friendlyWalletError(
    String operation,
    String kind,
    String rawMessage,
  ) {
    switch (kind) {
      case 'rejected':
        return 'Wallet request rejected.';
      case 'locked_wallet':
        return 'Wallet is locked. Unlock it and retry.';
      case 'insufficient_funds':
        return 'Insufficient funds to complete this transaction.';
      case 'revert':
        return 'Transaction reverted by contract. Check pool state and token approvals.';
      default:
        return 'Wallet $operation failed: $rawMessage';
    }
  }

  void _setWalletError({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    required String flow,
  }) {
    final message = _normalizeWalletErrorMessage(error);
    final kind = _classifyWalletError(message);
    _errorMessage = _friendlyWalletError(operation, kind, message);
    notifyListeners();

    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('wallet.operation', operation);
        scope.setTag('wallet.error_kind', kind);
        scope.setTag('wallet.flow', flow);
        scope.setTag('wallet.platform', kIsWeb ? 'web' : 'mobile');
        scope.setContexts('wallet_error', {
          'walletAddress': _walletAddress,
          'walletErrorMessage': message,
        });
      },
    );
  }

  Future<void> disconnect() async {
    final privy = _privy;
    if (privy != null && !kIsWeb) {
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
