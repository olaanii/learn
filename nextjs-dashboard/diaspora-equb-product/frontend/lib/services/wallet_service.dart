import 'package:flutter/foundation.dart';
import 'package:reown_core/reown_core.dart' show PairingMetadata;
import 'package:reown_sign/reown_sign.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

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

  bool get isConnected => _session != null && _walletAddress != null;
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

  /// Initiate a WalletConnect pairing. Returns the pairing URI for QR display.
  /// On mobile, attempts to deep-link to MetaMask.
  Future<String?> connect() async {
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
      // Request Creditcoin Testnet (EIP-155 chain)
      const chainId = 'eip155:${AppConfig.chainId}';

      // optionalNamespaces (requiredNamespaces is deprecated in WalletConnect v2)
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

      // Try to open MetaMask (deep link, then universal link fallback) so user can approve
      if (_pairingUri != null) {
        await _tryOpenWallet(_pairingUri!);
      }

      // Wait for the wallet to approve the session
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
    if (_signClient == null || _session == null || _walletAddress == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    try {
      const chainId = 'eip155:${AppConfig.chainId}';

      // Build the eth_sendTransaction params
      final txParams = {
        'from': _walletAddress,
        'to': unsignedTx['to'],
        'data': unsignedTx['data'],
        'value': _toHex(unsignedTx['value'] ?? '0'),
        'gas': _toHex(unsignedTx['estimatedGas'] ?? '300000'),
      };

      // Try to bring the wallet to foreground so user can confirm the TX
      await _tryOpenWallet(null);

      // Request the wallet to sign and send
      final result = await _signClient!.request(
        topic: _session!.topic,
        chainId: chainId,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [txParams],
        ),
      );

      // result is the transaction hash
      final txHash = result.toString();
      debugPrint('[WalletService] TX sent: $txHash');
      return txHash;
    } catch (e) {
      _errorMessage = 'Transaction failed: $e';
      notifyListeners();
      return null;
    }
  }

  /// Sign a personal message (e.g. for authentication).
  Future<String?> personalSign(String message) async {
    if (_signClient == null || _session == null || _walletAddress == null) {
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
    final value = BigInt.tryParse(decimalOrHex) ?? BigInt.zero;
    return '0x${value.toRadixString(16)}';
  }

  /// Try to open MetaMask or another wallet via deep link.
  /// Tries custom scheme first, then MetaMask universal link as fallback (helps on Android).
  Future<void> _tryOpenWallet(String? uri) async {
    try {
      if (uri != null) {
        final encodedUri = Uri.encodeComponent(uri);
        // 1. Deep link (works best on iOS; can fail on Android)
        final deepLink = Uri.parse('metamask://wc?uri=$encodedUri');
        final launched = await launchUrl(deepLink, mode: LaunchMode.externalApplication);
        if (launched) return;
        // 2. Universal link fallback (more reliable when custom scheme is blocked)
        final universalLink = Uri.parse('https://link.metamask.io/wc?uri=$encodedUri');
        await launchUrl(universalLink, mode: LaunchMode.externalApplication);
      } else {
        // Bring MetaMask to foreground for pending sign request
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
