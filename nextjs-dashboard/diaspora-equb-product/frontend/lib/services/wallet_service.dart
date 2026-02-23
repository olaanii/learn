import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, kIsWeb;
import 'package:reown_core/reown_core.dart' show PairingMetadata;
import 'package:reown_sign/reown_sign.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import 'ethereum_provider_stub.dart'
    if (dart.library.js_interop) 'ethereum_provider_web.dart' as eth_provider;

/// Service that manages WalletConnect v2 sessions for client-side TX signing.
///
/// Flow:
/// 1. [connect] - Initiates a WalletConnect pairing. Returns a URI for QR code
///    or deep-links to MetaMask mobile.
/// 2. [signAndSendTransaction] - Takes an unsigned TX object (from the backend)
///    and requests the connected wallet to sign & broadcast it.
/// 3. [disconnect] - Ends the WalletConnect session.
class WalletService extends ChangeNotifier {
  ReownSignClient? _signClient;
  SessionData? _session;
  String? _walletAddress;
  String? _pairingUri;
  bool _isConnecting = false;
  String? _errorMessage;

  // ─── Getters ────────────────────────────────────────────────────────────────

  bool get isConnected =>
      _walletAddress != null &&
      (kIsWeb ? eth_provider.hasInjectedProvider : _session != null);
  String? get walletAddress => _walletAddress;
  String? get pairingUri => _pairingUri;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  SessionData? get session => _session;

  // ─── Initialization ─────────────────────────────────────────────────────────

  /// Initialize the WalletConnect Web3App instance.
  Future<void> init() async {
    if (_signClient != null) return;

    const projectId = AppConfig.walletConnectProjectId;
    if (projectId.isEmpty) {
      debugPrint(
        '[WalletService] No WalletConnect project ID configured. '
        'Set WALLETCONNECT_PROJECT_ID via --dart-define.',
      );
      return;
    }

    _signClient = await ReownSignClient.createInstance(
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'Diaspora Equb',
        description: 'Decentralized Rotating Savings on Creditcoin',
        url: 'https://diaspora-equb.app',
        icons: ['https://diaspora-equb.app/icon.png'],
      ),
    );

    // Restore existing sessions
    final sessions = _signClient!.sessions.getAll();
    if (sessions.isNotEmpty) {
      _session = sessions.first;
      _extractWalletAddress();
      notifyListeners();
    }
  }

  // ─── Connect ────────────────────────────────────────────────────────────────

  /// Connect to a wallet.
  /// On web: uses the injected MetaMask browser extension (window.ethereum).
  /// On mobile: uses WalletConnect v2 with deep-link to MetaMask.
  Future<String?> connect() async {
    // On web, prefer the injected MetaMask extension
    if (kIsWeb && eth_provider.hasInjectedProvider) {
      return _connectViaInjected();
    }

    // Mobile: use WalletConnect
    return _connectViaWalletConnect();
  }

  Future<String?> _connectViaInjected() async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final address = await eth_provider.connectViaInjectedProvider();
      if (address != null) {
        _walletAddress = address;
        _isConnecting = false;
        notifyListeners();
        debugPrint(
            '[WalletService] Connected via MetaMask extension: $address');
        return address;
      }
      _errorMessage = 'No accounts returned from MetaMask';
    } catch (e) {
      _errorMessage = 'MetaMask connection failed: $e';
    }

    _isConnecting = false;
    notifyListeners();
    return null;
  }

  Future<String?> _connectViaWalletConnect() async {
    if (_signClient == null) await init();
    if (_signClient == null) {
      _errorMessage = 'WalletConnect not initialized. Check project ID.';
      notifyListeners();
      return null;
    }

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const chainId = 'eip155:${AppConfig.chainId}';

      final connectResponse = await _signClient!.connect(
        optionalNamespaces: {
          'eip155': const RequiredNamespace(
            chains: [chainId],
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'personal_sign',
              'eth_sign',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      _pairingUri = connectResponse.uri?.toString();
      notifyListeners();

      if (_pairingUri != null) {
        await _tryOpenWallet(_pairingUri!);
      }

      _session = await connectResponse.session.future;
      _extractWalletAddress();

      _isConnecting = false;
      _pairingUri = null;
      notifyListeners();

      return _walletAddress;
    } catch (e) {
      _errorMessage = 'Wallet connection failed: $e';
      _isConnecting = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Sign & Send Transaction ────────────────────────────────────────────────

  /// Takes an unsigned TX object (returned by the backend build/* endpoints)
  /// and sends it to the connected wallet for signing and broadcasting.
  ///
  /// Returns the transaction hash on success, or null on failure.
  Future<String?> signAndSendTransaction(
    Map<String, dynamic> unsignedTx,
  ) async {
    if (_walletAddress == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    final chainIdRaw = unsignedTx['chainId'];
    final chainIdHex = chainIdRaw != null
        ? _toHex(
            chainIdRaw is int ? chainIdRaw.toString() : chainIdRaw.toString())
        : _toHex(AppConfig.chainId.toString());

    final txParams = {
      'from': _walletAddress,
      'to': unsignedTx['to'],
      'data': unsignedTx['data'],
      'value': _toHex(unsignedTx['value'] ?? '0'),
      'gas': _toHex(unsignedTx['estimatedGas'] ?? '300000'),
      'chainId': chainIdHex,
    };

    // On web, use the injected provider
    if (kIsWeb && eth_provider.hasInjectedProvider) {
      try {
        final txHash = await eth_provider.sendTransactionViaInjected(txParams);
        if (txHash != null) {
          debugPrint('[WalletService] TX sent via MetaMask extension: $txHash');
          return txHash;
        }
        _errorMessage = 'Transaction rejected';
        notifyListeners();
        return null;
      } catch (e) {
        _errorMessage = _formatTxFailureMessage(e);
        notifyListeners();
        return null;
      }
    }

    // Mobile: use WalletConnect
    if (_signClient == null || _session == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    try {
      const chainId = 'eip155:${AppConfig.chainId}';
      await _tryOpenWallet(null);

      final result = await _signClient!.request(
        topic: _session!.topic,
        chainId: chainId,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [txParams],
        ),
      );

      final txHash = result.toString();
      debugPrint('[WalletService] TX sent: $txHash');
      return txHash;
    } catch (e) {
      _errorMessage = _formatTxFailureMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Build user-facing message for a failed tx. If the error contains a 4-byte
  /// selector (e.g. 0xb39d8e65), append a hint about contract revert / token approval.
  static String _formatTxFailureMessage(Object e) {
    final s = e.toString();
    final base = 'Transaction failed: $e';
    // Match 0x followed by 8 hex chars (custom error selector)
    if (RegExp(r'0x[0-9a-fA-F]{8}').hasMatch(s)) {
      return '$base\n(Contract reverted. For token pools, approve the token first; or check Blockscout for the revert reason.)';
    }
    return base;
  }

  /// Sign a personal message (e.g. for authentication).
  Future<String?> personalSign(String message) async {
    if (_walletAddress == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    // On web, use the injected MetaMask extension
    if (kIsWeb && eth_provider.hasInjectedProvider) {
      try {
        final sig = await eth_provider.personalSignViaInjected(
            message, _walletAddress!);
        if (sig != null) return sig;
        _errorMessage = 'Signing rejected';
        notifyListeners();
        return null;
      } catch (e) {
        _errorMessage = 'Signing failed: $e';
        notifyListeners();
        return null;
      }
    }

    // Mobile: use WalletConnect
    if (_signClient == null || _session == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    try {
      const chainId = 'eip155:${AppConfig.chainId}';
      final hexMessage =
          '0x${message.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';

      final result = await _signClient!.request(
        topic: _session!.topic,
        chainId: chainId,
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [hexMessage, _walletAddress],
        ),
      );

      return result.toString();
    } catch (e) {
      _errorMessage = 'Signing failed: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    if (_signClient != null && _session != null) {
      try {
        await _signClient!.disconnect(
          topic: _session!.topic,
          reason: const ReownSignError(
            code: 6000,
            message: 'User disconnected',
          ),
        );
      } catch (_) {
        // Ignore disconnect errors
      }
    }

    _session = null;
    _walletAddress = null;
    _pairingUri = null;
    notifyListeners();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _extractWalletAddress() {
    if (_session == null) return;

    // Extract the first account from the session namespaces
    final accounts = _session!.namespaces['eip155']?.accounts ?? [];
    if (accounts.isNotEmpty) {
      // Account format: "eip155:102031:0xABC..."
      final parts = accounts.first.split(':');
      if (parts.length >= 3) {
        _walletAddress = parts[2];
      }
    }
  }

  /// Convert a decimal string to hex string with 0x prefix.
  String _toHex(String decimalOrHex) {
    if (decimalOrHex.startsWith('0x')) return decimalOrHex;

    // Integer strings (e.g. gas, chainId, wei values)
    final intValue = BigInt.tryParse(decimalOrHex);
    if (intValue != null) {
      return '0x${intValue.toRadixString(16)}';
    }

    // Decimal strings (e.g. "2.000000000000000000" native CTC amount)
    // are interpreted as 18-decimal units and converted to wei.
    final looksDecimal = decimalOrHex.contains('.');
    if (looksDecimal) {
      try {
        final wei = EtherAmountEx.parseUnits(decimalOrHex, 18);
        return '0x${wei.toRadixString(16)}';
      } catch (_) {
        // fall through to zero for malformed values
      }
    }

    final value = BigInt.zero;
    return '0x${value.toRadixString(16)}';
  }

  /// Try to open MetaMask or another wallet via deep link.
  /// On web, MetaMask is a browser extension — deep links don't apply and
  /// would navigate the tab to about:blank, so we skip them entirely.
  Future<void> _tryOpenWallet(String? uri) async {
    if (kIsWeb) return;

    try {
      if (uri != null) {
        final encodedUri = Uri.encodeComponent(uri);
        final deepLink = Uri.parse('metamask://wc?uri=$encodedUri');
        final launched =
            await launchUrl(deepLink, mode: LaunchMode.externalApplication);
        if (launched) return;
        final universalLink =
            Uri.parse('https://link.metamask.io/wc?uri=$encodedUri');
        await launchUrl(universalLink, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse('metamask://'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      // Deep link not available; user can scan QR code or open wallet manually
    }
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
