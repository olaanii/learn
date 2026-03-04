import 'dart:async';
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

  // Transactions: combined across all tokens, sorted by block number
  List<Map<String, dynamic>> _transactions = [];

  int _loadingCount = 0;
  String? _errorMessage;
  String? _lastTxHash;

  WalletProvider(this._api, this._walletService);

  /// The formatted balance for the currently selected token.
  String get balance => _balances[_selectedToken]?['formatted'] ?? '0.00';

  /// The raw balance for the currently selected token.
  String get rawBalance => _balances[_selectedToken]?['balance'] ?? '0';

  /// The currently selected token symbol.
  String get token => _selectedToken;

  /// Decimals for the currently selected token.
  int get decimals => _balances[_selectedToken]?['decimals'] ?? 6;

  /// All loaded token balances (for multi-token display).
  Map<String, Map<String, dynamic>> get allBalances => _balances;

  /// Get the formatted balance for a specific token.
  String balanceOf(String tokenSymbol) =>
      _balances[tokenSymbol]?['formatted'] ?? '0.00';

  Map<String, double> get rates => _rates;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isLoading => _loadingCount > 0;
  String? get errorMessage => _errorMessage;
  String? get lastTxHash => _lastTxHash;

  void _startLoading() {
    _loadingCount++;
    notifyListeners();
  }

  void _stopLoading() {
    _loadingCount--;
    if (_loadingCount < 0) _loadingCount = 0;
    notifyListeners();
  }

  /// Switch the selected token (transactions already include all tokens).
  void selectToken(String tokenSymbol, {String? walletAddress}) {
    if (_selectedToken == tokenSymbol) return;
    _selectedToken = tokenSymbol;
    notifyListeners();
  }

  /// Load the balance for a specific token.
  /// Pass [tokenAddress] for arbitrary ERC-20 contracts not in the backend's known list.
  Future<void> loadBalance(String walletAddress,
      {String token = 'USDC', String? tokenAddress}) async {
    _startLoading();
    _errorMessage = null;

    try {
      final data = await _api.getTokenBalance(walletAddress,
          token: token, tokenAddress: tokenAddress);
      final key = (data['symbol'] ?? token).toString().toUpperCase();
      _balances[key] = {
        'formatted': data['formatted'] ?? '0.00',
        'balance': data['balance'] ?? '0',
        'decimals': data['decimals'] ?? 6,
        'token': data['token'] ?? token,
      };
    } catch (e) {
      _errorMessage = 'Failed to load $token balance';
    }

    _stopLoading();
  }

  /// Load balances for all supported tokens (USDC + USDT).
  Future<void> loadAllBalances(String walletAddress) async {
    await Future.wait([
      loadBalance(walletAddress, token: 'USDC'),
      loadBalance(walletAddress, token: 'USDT'),
    ]);
  }

  /// Load transaction history for a wallet.
  /// Fetches transactions using optional server-side filters.
  Future<void> loadTransactions(
    String walletAddress, {
    String token = 'ALL',
    int limit = 50,
    int? fromTimestamp,
    int? toTimestamp,
    String? direction,
    String? status,
    String? cursor,
  }) async {
    _startLoading();
    _errorMessage = null;
    _transactions = [];

    try {
      final data = await _api.getTokenTransactions(
        walletAddress,
        token: token,
        limit: limit,
        fromTimestamp: fromTimestamp,
        toTimestamp: toTimestamp,
        direction: direction,
        status: status,
        cursor: cursor,
      );
      final list = data.whereType<Map<String, dynamic>>().toList();
      list.sort((a, b) {
        final bBlock = (b['blockNumber'] as num?) ?? 0;
        final aBlock = (a['blockNumber'] as num?) ?? 0;
        return bBlock.compareTo(aBlock);
      });
      _transactions = list.take(limit).toList();
    } catch (e) {
      _errorMessage = 'Failed to load transactions';
    }

    _stopLoading();
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
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Please connect via WalletConnect.';
        _stopLoading();
        return null;
      }

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }

      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Transaction failed: $e';
      _stopLoading();
      return null;
    }
  }

  /// Request faucet tokens (minted by deployer on backend).
  Future<Map<String, dynamic>?> requestFaucet({
    required String walletAddress,
    double amount = 1000,
    String token = 'USDC',
  }) async {
    _startLoading();
    _errorMessage = null;

    try {
      final data = await _api.requestFaucet(
        walletAddress: walletAddress,
        amount: amount,
        token: token,
      );
      _stopLoading();
      return data;
    } catch (e) {
      _errorMessage = 'Failed to build faucet transaction';
      _stopLoading();
      return null;
    }
  }

  // ─── Pool / Contract Transaction Helpers ──────────────────────────────────

  /// Build unsigned TX to deposit collateral on-chain, then sign via wallet.
  Future<String?> buildAndSignCollateralDeposit(String amount) async {
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Connect via WalletConnect to sign.';
        _stopLoading();
        return null;
      }

      final unsignedTx = await _api.buildDepositCollateral(amount);
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }
      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Collateral deposit failed: $e';
      _stopLoading();
      return null;
    }
  }

  /// Build unsigned TX to release collateral on-chain, then sign via wallet.
  Future<String?> buildAndSignCollateralRelease({
    required String userAddress,
    required String amount,
  }) async {
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Connect via WalletConnect to sign.';
        _stopLoading();
        return null;
      }

      final unsignedTx = await _api.buildReleaseCollateral(
        userAddress: userAddress,
        amount: amount,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }
      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Collateral release failed: $e';
      _stopLoading();
      return null;
    }
  }

  /// Build unsigned contribution TX, then sign and send via wallet.
  /// For ERC-20 pools, approve must be done separately first.
  Future<String?> buildAndSignContribution({
    required int onChainPoolId,
    required String contributionAmount,
    String? tokenAddress,
  }) async {
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Connect via WalletConnect to sign.';
        _stopLoading();
        return null;
      }

      final unsignedTx = await _api.buildContribute(
        onChainPoolId: onChainPoolId,
        contributionAmount: contributionAmount,
        tokenAddress: tokenAddress,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
      }
      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Contribution failed: $e';
      _stopLoading();
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
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Connect via WalletConnect to sign.';
        _stopLoading();
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
      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Transfer failed: $e';
      _stopLoading();
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
    _startLoading();
    _errorMessage = null;
    _lastTxHash = null;

    try {
      if (!_walletService.isConnected) {
        _errorMessage =
            'Wallet not connected. Connect via WalletConnect to sign.';
        _stopLoading();
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
      _stopLoading();
      return txHash;
    } catch (e) {
      _errorMessage = 'Withdraw failed: $e';
      _stopLoading();
      return null;
    }
  }

  /// Refresh balances + transactions after a successful TX.
  /// Loads immediately, then again after a delay to catch indexer lag.
  Future<void> refreshAfterTx(String walletAddress, {String? token}) async {
    await loadAllBalances(walletAddress);
    await loadTransactions(walletAddress);
    unawaited(Future.delayed(const Duration(seconds: 2), () async {
      await loadAllBalances(walletAddress);
      await loadTransactions(walletAddress);
    }));
  }

  /// Load all wallet data (USDC, USDT, optional native tCTC/CTC, transactions, rates).
  /// Pass [nativeSymbol] (e.g. from NetworkProvider.nativeSymbol) to load native balance for pool status.
  Future<void> loadAll(String walletAddress, {String? token, String? nativeSymbol}) async {
    final tasks = <Future<void>>[
      loadBalance(walletAddress, token: 'USDC'),
      loadBalance(walletAddress, token: 'USDT'),
      loadTransactions(walletAddress),
      loadExchangeRates(),
    ];
    if (nativeSymbol != null && nativeSymbol.isNotEmpty) {
      tasks.add(loadBalance(walletAddress, token: nativeSymbol));
    }
    await Future.wait(tasks);
  }
}
