import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class WalletProvider extends ChangeNotifier {
  final ApiClient _api;

  // Balance
  String _balance = '0.00';
  String _rawBalance = '0';
  String _token = 'USDC';
  int _decimals = 6;

  // Exchange rates
  Map<String, double> _rates = {};

  // Transactions
  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = false;
  String? _errorMessage;

  WalletProvider(this._api);

  String get balance => _balance;
  String get rawBalance => _rawBalance;
  String get token => _token;
  int get decimals => _decimals;
  Map<String, double> get rates => _rates;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load the USDC balance for a wallet.
  Future<void> loadBalance(String walletAddress, {String token = 'USDC'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getTokenBalance(walletAddress, token: token);
      _balance = data['formatted'] ?? '0.00';
      _rawBalance = data['balance'] ?? '0';
      _token = data['token'] ?? token;
      _decimals = data['decimals'] ?? 6;
    } catch (e) {
      _errorMessage = 'Failed to load balance';
    }

    _isLoading = false;
    notifyListeners();
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
        _rates = ratesData.map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()));
      }
    } catch (e) {
      _errorMessage = 'Failed to load exchange rates';
    }
    notifyListeners();
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

  /// Load all wallet data at once.
  Future<void> loadAll(String walletAddress, {String token = 'USDC'}) async {
    await Future.wait([
      loadBalance(walletAddress, token: token),
      loadTransactions(walletAddress, token: token),
      loadExchangeRates(),
    ]);
  }
}
