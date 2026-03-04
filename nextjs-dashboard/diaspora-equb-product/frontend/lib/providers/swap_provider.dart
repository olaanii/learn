import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class SwapProvider extends ChangeNotifier {
  final ApiClient _api;

  String _fromToken = 'CTC';
  String _toToken = 'USDC';
  double? _quote;
  double? _priceImpact;
  bool _isLoadingQuote = false;
  bool _isSwapping = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recentSwaps = [];

  SwapProvider(this._api);

  String get fromToken => _fromToken;
  String get toToken => _toToken;
  double? get quote => _quote;
  double? get priceImpact => _priceImpact;
  bool get isLoadingQuote => _isLoadingQuote;
  bool get isSwapping => _isSwapping;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get recentSwaps => _recentSwaps;

  void setFromToken(String token) {
    if (token == _toToken) {
      _toToken = _fromToken;
    }
    _fromToken = token;
    _quote = null;
    notifyListeners();
  }

  void setToToken(String token) {
    if (token == _fromToken) {
      _fromToken = _toToken;
    }
    _toToken = token;
    _quote = null;
    notifyListeners();
  }

  void swapDirection() {
    final temp = _fromToken;
    _fromToken = _toToken;
    _toToken = temp;
    _quote = null;
    notifyListeners();
  }

  Future<void> fetchQuote(double amount) async {
    if (amount <= 0) {
      _quote = null;
      notifyListeners();
      return;
    }

    _isLoadingQuote = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getSwapQuote(
        fromToken: _fromToken,
        toToken: _toToken,
        amount: amount.toString(),
      );
      _quote = (data['estimatedOutput'] as num?)?.toDouble();
      _priceImpact = (data['priceImpact'] as num?)?.toDouble();
    } catch (e) {
      _errorMessage = 'Quote unavailable';
      _quote = null;
    }

    _isLoadingQuote = false;
    notifyListeners();
  }

  Future<bool> executeSwap(double amount) async {
    _isSwapping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.buildSwapTx(
        fromToken: _fromToken,
        toToken: _toToken,
        amount: amount.toString(),
      );
      _isSwapping = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Swap failed';
      _isSwapping = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchRecentSwaps() async {
    try {
      final data = await _api.getSwapHistory();
      _recentSwaps = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      notifyListeners();
    } catch (_) {}
  }
}
