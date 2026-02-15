import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final ApiClient _api;
  final WalletService _walletService;

  // Currently selected token
  String _selectedToken = 'USDC';

  // Per-token balances: { 'USDC': { formatted, balance, decimals }, 'USDT': {...} }
  final Map<String, Map<String, dynamic>> _balances = {};

  // Exchange rates
  Map<String, double> _rates = {};

  // Transactions (for the selected token)
  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = false;
  String? _errorMessage;
  String? _lastTxHash;

  WalletProvider(this._api, this._walletService);

  /// The formatted balance for the currently selected token.
  String get balance =>
      _balances[_selectedToken]?['formatted'] ?? '0.00';

  /// The raw balance for the currently selected token.
  String get rawBalance =>
      _balances[_selectedToken]?['balance'] ?? '0';

  /// The currently selected token symbol.
  String get token => _selectedToken;

  /// Decimals for the currently selected token.
  int get decimals =>
      _balances[_selectedToken]?['decimals'] ?? 6;

  /// All loaded token balances (for multi-token display).
  Map<String, Map<String, dynamic>> get allBalances => _balances;

  /// Get the formatted balance for a specific token.
  String balanceOf(String tokenSymbol) =>
      _balances[tokenSymbol]?['formatted'] ?? '0.00';

  Map<String, double> get rates => _rates;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastTxHash => _lastTxHash;

  /// Switch the selected token and reload transactions.
  void selectToken(String tokenSymbol, {String? walletAddress}) {
    if (_selectedToken == tokenSymbol) return;
    _selectedToken = tokenSymbol;
    notifyListeners();
    // Optionally reload transactions for the new token
    if (walletAddress != null) {
      loadTransactions(walletAddress, token: tokenSymbol);
    }
  }

  /// Load the balance for a specific token.
  Future<void> loadBalance(String walletAddress,
      {String token = 'USDC'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getTokenBalance(walletAddress, token: token);
      _balances[token.toUpperCase()] = {
        'formatted': data['formatted'] ?? '0.00',
        'balance': data['balance'] ?? '0',
        'decimals': data['decimals'] ?? 6,
        'token': data['token'] ?? token,
      };
    } catch (e) {
      _errorMessage = 'Failed to load $token balance';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load balances for all supported tokens (USDC + USDT).
  Future<void> loadAllBalances(String walletAddress) async {
    await Future.wait([
      loadBalance(walletAddress, token: 'USDC'),
      loadBalance(walletAddress, token: 'USDT'),
    ]);
  }

  /// Load recent transactions for a wallet.
  Future<void> loadTransactions(String walletAddress,
      {String token = 'USDC', int limit = 20}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getTokenTransactions(
        walletAddress,
        token: token,
        limit: limit,
      );
      _transactions = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _errorMessage = 'Failed to load transactions';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load exchange rates.
  Future<void> loadExchangeRates() async {
    try {
      final data = await _api.getExchangeRates();
      final ratesData = data['rates'];
      if (ratesData is Map) {
        _rates = ratesData.map((key, value) =>
            MapEntry(key.toString(), (value as num).toDouble()));
      }
    } catch (e) {
      _errorMessage = 'Failed to load exchange rates';
    }
    notifyListeners();
  }

  // ─── Wallet Signing Methods ─────────────────────────────────────────────────

  /// Get an unsigned TX from the backend, then sign & send it via WalletConnect.
  /// Returns the TX hash on success, or null on failure.
  Future<String?> signAndSend(Map<String, dynamic> unsignedTx) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      if (!_walletService.isConnected) {
        _errorMessage = 'Wallet not connected. Please connect via WalletConnect.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Transaction failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Request faucet tokens (builds unsigned tx for the user to sign).
  Future<Map<String, dynamic>?> requestFaucet({
    required String walletAddress,
    double amount = 1000,
    String token = 'USDC',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.requestFaucet(
        walletAddress: walletAddress,
        amount: amount,
        token: token,
      );
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _errorMessage = 'Failed to build faucet transaction';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build an unsigned transfer transaction.
  Future<Map<String, dynamic>?> buildTransfer({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
  }) async {
    try {
      return await _api.buildTransfer(
        from: from,
        to: to,
        amount: amount,
        token: token,
      );
    } catch (e) {
      _errorMessage = 'Failed to build transfer';
      notifyListeners();
      return null;
    }
  }

  /// Build an unsigned withdraw transaction.
  Future<Map<String, dynamic>?> buildWithdraw({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
    String network = 'ERC-20',
  }) async {
    try {
      return await _api.buildWithdraw(
        from: from,
        to: to,
        amount: amount,
        token: token,
        network: network,
      );
    } catch (e) {
      _errorMessage = 'Failed to build withdraw';
      notifyListeners();
      return null;
    }
  }

  /// Build unsigned transfer TX, then sign and send via WalletConnect (MetaMask).
  /// Returns the transaction hash on success, or null on failure.
  Future<String?> buildAndSignTransfer({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      if (!_walletService.isConnected) {
        _errorMessage = 'Wallet not connected. Connect via WalletConnect to sign.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final unsignedTx = await _api.buildTransfer(
        from: from,
        to: to,
        amount: amount,
        token: token,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }
      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Transfer failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build unsigned withdraw TX, then sign and send via WalletConnect (MetaMask).
  /// Returns the transaction hash on success, or null on failure.
  Future<String?> buildAndSignWithdraw({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
    String network = 'ERC-20',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      if (!_walletService.isConnected) {
        _errorMessage = 'Wallet not connected. Connect via WalletConnect to sign.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final unsignedTx = await _api.buildWithdraw(
        from: from,
        to: to,
        amount: amount,
        token: token,
        network: network,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }
      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Withdraw failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load all wallet data at once (both USDC + USDT balances).
  Future<void> loadAll(String walletAddress, {String? token}) async {
    final activeToken = token ?? _selectedToken;
    await Future.wait([
      // Load balances for both stablecoins
      loadBalance(walletAddress, token: 'USDC'),
      loadBalance(walletAddress, token: 'USDT'),
      // Load transactions for the active token
      loadTransactions(walletAddress, token: activeToken),
      loadExchangeRates(),
    ]);
  }
}
