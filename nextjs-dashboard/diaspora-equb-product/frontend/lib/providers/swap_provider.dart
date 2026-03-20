import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';

class SwapProvider extends ChangeNotifier {
  SwapProvider(this._api, this._walletService);

  static const int _defaultSlippageBps = 100;

  final ApiClient _api;
  final WalletService _walletService;

  final Map<String, String> _tokenAddresses = {};
  final List<Map<String, dynamic>> _recentSwaps = [];

  String _nativeSymbol = AppConfig.nativeSymbol;
  String _fromToken = AppConfig.nativeSymbol;
  String _toToken = 'USDC';
  String? _quote;
  String? _quoteRaw;
  String? _fee;
  double? _priceImpact;
  String? _errorMessage;
  String? _statusMessage;
  String? _lastApprovalTxHash;
  String? _lastTxHash;
  String? _lastAmountText;
  String? _routerAddress;
  String? _allowanceRaw;
  bool _routerConfigured = false;
  bool _isLoadingStatus = false;
  bool _isLoadingQuote = false;
  bool _isCheckingAllowance = false;
  bool _isApproving = false;
  bool _isSwapping = false;
  bool _hasSufficientAllowance = true;

  String get nativeSymbol => _nativeSymbol;
  String get fromToken => _fromToken;
  String get toToken => _toToken;
  String? get quote => _quote;
  String? get quoteRaw => _quoteRaw;
  String? get fee => _fee;
  double? get priceImpact => _priceImpact;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  String? get lastApprovalTxHash => _lastApprovalTxHash;
  String? get lastTxHash => _lastTxHash;
  String? get routerAddress => _routerAddress;
  String? get allowanceRaw => _allowanceRaw;
  bool get routerConfigured => _routerConfigured;
  bool get isLoadingStatus => _isLoadingStatus;
  bool get isLoadingQuote => _isLoadingQuote;
  bool get isCheckingAllowance => _isCheckingAllowance;
  bool get isApproving => _isApproving;
  bool get isSwapping => _isSwapping;
  bool get isBusy =>
      _isLoadingStatus ||
      _isLoadingQuote ||
      _isCheckingAllowance ||
      _isApproving ||
      _isSwapping;
  bool get requiresApproval =>
      !_isNativeToken(_fromToken) && !_hasSufficientAllowance;
  List<Map<String, dynamic>> get recentSwaps => List.unmodifiable(_recentSwaps);
  List<String> get supportedTokenSymbols =>
      List.unmodifiable(_tokenAddresses.keys);
  List<String> get availableTokens => [
        _nativeSymbol,
        ..._tokenAddresses.keys.where((symbol) => symbol != _nativeSymbol),
      ];

  String? get readinessMessage {
    if (!_routerConfigured) {
      return 'Swap router is not configured for this environment yet.';
    }
    if (_tokenAddresses.isEmpty) {
      return 'No swap tokens are configured for this network yet.';
    }
    return null;
  }

  Future<void> loadStatus() async {
    _isLoadingStatus = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getSwapStatus();
      _routerConfigured = data['routerConfigured'] == true;

      final statusNativeSymbol = (data['nativeSymbol'] as String?)?.trim();
      if (statusNativeSymbol != null && statusNativeSymbol.isNotEmpty) {
        _nativeSymbol = statusNativeSymbol;
      }
      _routerAddress = (data['routerAddress'] as String?)?.trim();

      _tokenAddresses
        ..clear()
        ..addEntries(
          ((data['supportedTokens'] as List?) ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .where((entry) {
            final symbol = (entry['symbol'] as String?)?.trim();
            final address = (entry['address'] as String?)?.trim();
            return symbol != null &&
                symbol.isNotEmpty &&
                address != null &&
                address.isNotEmpty;
          }).map(
            (entry) => MapEntry(
              (entry['symbol'] as String).trim().toUpperCase(),
              (entry['address'] as String).trim(),
            ),
          ),
        );

      if (_fromToken != _nativeSymbol &&
          !_tokenAddresses.containsKey(_fromToken)) {
        _fromToken = _nativeSymbol;
      }

      if (_toToken == _nativeSymbol || !_tokenAddresses.containsKey(_toToken)) {
        _toToken = _preferredToToken();
      }

      _resetAllowanceState();
    } catch (error) {
      _errorMessage = _extractMessage(
        error,
        fallback: 'Failed to load swap status',
      );
    }

    _isLoadingStatus = false;
    notifyListeners();
  }

  void setFromToken(String token) {
    if (token == _toToken) {
      _toToken = _fromToken;
    }
    _fromToken = token;
    _clearQuote();
    _resetAllowanceState();
    notifyListeners();
  }

  void setToToken(String token) {
    if (token == _fromToken) {
      _fromToken = _toToken;
    }
    _toToken = token;
    _clearQuote();
    _resetAllowanceState();
    notifyListeners();
  }

  void swapDirection() {
    final temp = _fromToken;
    _fromToken = _toToken;
    _toToken = temp;
    _clearQuote();
    _resetAllowanceState();
    notifyListeners();
  }

  Future<void> fetchQuote(String amountText, {String? walletAddress}) async {
    final parsedAmount = double.tryParse(amountText.trim()) ?? 0;
    _lastAmountText = amountText.trim();

    if (parsedAmount <= 0 || _fromToken == _toToken) {
      _clearQuote();
      _resetAllowanceState();
      notifyListeners();
      return;
    }

    _isLoadingQuote = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getSwapQuote(
        fromToken: _tokenForApi(_fromToken),
        toToken: _tokenForApi(_toToken),
        amountIn: amountText.trim(),
      );

      _quote = (data['estimatedOutput'] as String?)?.trim();
      _quoteRaw = (data['estimatedOutputRaw'] as String?)?.trim();
      _fee = (data['fee'] as String?)?.trim();
      final amountInRaw = (data['amountInRaw'] as String?)?.trim();
      _priceImpact = double.tryParse(
        ((data['priceImpactPct'] ?? data['priceImpact']) as String?)
                ?.replaceAll('%', '') ??
            '',
      );

      if (_isNativeToken(_fromToken)) {
        _hasSufficientAllowance = true;
        _allowanceRaw = null;
      } else if (walletAddress != null &&
          walletAddress.isNotEmpty &&
          amountInRaw != null &&
          amountInRaw.isNotEmpty) {
        await _checkAllowance(walletAddress, amountInRaw);
      } else {
        _hasSufficientAllowance = false;
      }
    } catch (error) {
      _errorMessage = _extractMessage(error, fallback: 'Quote unavailable');
      _clearQuote();
      _resetAllowanceState();
    }

    _isLoadingQuote = false;
    notifyListeners();
  }

  Future<String?> executeSwap({
    required String amountText,
    required String walletAddress,
  }) async {
    final parsedAmount = double.tryParse(amountText.trim()) ?? 0;
    if (parsedAmount <= 0) {
      _errorMessage = 'Enter a valid swap amount';
      notifyListeners();
      return null;
    }

    if (readinessMessage != null) {
      _errorMessage = readinessMessage;
      notifyListeners();
      return null;
    }

    if (!_walletService.isConnected) {
      _errorMessage = 'Connect your wallet to continue';
      notifyListeners();
      return null;
    }

    if (_quoteRaw == null || _lastAmountText != amountText.trim()) {
      await fetchQuote(amountText, walletAddress: walletAddress);
      if (_quoteRaw == null) {
        return null;
      }
    }

    _isSwapping = true;
    _errorMessage = null;
    _lastApprovalTxHash = null;
    _lastTxHash = null;
    _statusMessage = requiresApproval
        ? 'Approval required before swap'
        : 'Waiting for wallet confirmation';
    notifyListeners();

    try {
      final quoteData = await _api.getSwapQuote(
        fromToken: _tokenForApi(_fromToken),
        toToken: _tokenForApi(_toToken),
        amountIn: amountText.trim(),
      );
      final amountInRaw = (quoteData['amountInRaw'] as String?)?.trim();
      final estimatedOutputRaw =
          (quoteData['estimatedOutputRaw'] as String?)?.trim();

      if (amountInRaw == null || amountInRaw.isEmpty) {
        throw StateError('Swap amount could not be resolved');
      }
      if (estimatedOutputRaw == null || estimatedOutputRaw.isEmpty) {
        throw StateError('Swap output quote could not be resolved');
      }

      _quoteRaw = estimatedOutputRaw;

      if (!_isNativeToken(_fromToken)) {
        await _checkAllowance(walletAddress, amountInRaw);
      }

      if (requiresApproval) {
        _isApproving = true;
        _statusMessage = 'Waiting for token approval in wallet';
        notifyListeners();

        final approvalTx = await _api.buildSwapApprovalTx(
          fromToken: _tokenForApi(_fromToken),
          amountInRaw: amountInRaw,
        );
        final approvalHash =
            await _walletService.signAndSendTransaction(approvalTx);

        _isApproving = false;
        if (approvalHash == null) {
          _errorMessage =
              _walletService.errorMessage ?? 'Approval was rejected';
          _isSwapping = false;
          notifyListeners();
          return null;
        }
        _lastApprovalTxHash = approvalHash;
        _hasSufficientAllowance = true;
        _allowanceRaw = amountInRaw;
      }

      final minAmountOutRaw = _applySlippage(estimatedOutputRaw);
      final unsignedTx = await _api.buildSwapTx(
        fromToken: _tokenForApi(_fromToken),
        toToken: _tokenForApi(_toToken),
        amountInRaw: amountInRaw,
        minAmountOutRaw: minAmountOutRaw,
      );

      _statusMessage = 'Waiting for swap confirmation in wallet';
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Swap was rejected';
        _isSwapping = false;
        notifyListeners();
        return null;
      }

      _lastTxHash = txHash;
      _statusMessage = 'Swap submitted';
      _recordLocalSwap(
        txHash: txHash,
        walletAddress: walletAddress,
        amountIn: amountText.trim(),
        estimatedOutput: _quote ?? '0',
      );
      _isSwapping = false;
      notifyListeners();
      return txHash;
    } catch (error) {
      _errorMessage = _extractMessage(error, fallback: 'Swap failed');
      _isApproving = false;
      _isSwapping = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchRecentSwaps(String walletAddress) async {
    try {
      final data = await _api.getSwapHistory(wallet: walletAddress);
      _mergeRecentSwaps(
        data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
      notifyListeners();
    } catch (_) {}
  }

  void clearStatusMessage() {
    if (_statusMessage == null) {
      return;
    }
    _statusMessage = null;
    notifyListeners();
  }

  String _preferredToToken() {
    return _tokenAddresses.keys.isNotEmpty
        ? _tokenAddresses.keys.first
        : 'USDC';
  }

  bool _isNativeToken(String token) {
    final upper = token.trim().toUpperCase();
    return upper == 'CTC' ||
        upper == 'TCTC' ||
        upper == _nativeSymbol.toUpperCase();
  }

  String _tokenForApi(String token) {
    return _isNativeToken(token) ? _nativeSymbol : token.trim().toUpperCase();
  }

  void _resetAllowanceState() {
    _allowanceRaw = null;
    _hasSufficientAllowance = _isNativeToken(_fromToken);
    _isCheckingAllowance = false;
  }

  Future<void> _checkAllowance(
      String walletAddress, String requiredAmountRaw) async {
    if (_routerAddress == null ||
        _routerAddress!.isEmpty ||
        _isNativeToken(_fromToken)) {
      _hasSufficientAllowance = _isNativeToken(_fromToken);
      _allowanceRaw = null;
      return;
    }

    _isCheckingAllowance = true;
    notifyListeners();

    try {
      final data = await _api.getTokenAllowance(
        walletAddress: walletAddress,
        spender: _routerAddress!,
        token: _tokenForApi(_fromToken),
        tokenAddress: _tokenAddresses[_tokenForApi(_fromToken)],
        requiredAmountRaw: requiredAmountRaw,
      );
      _allowanceRaw = (data['allowanceRaw'] as String?)?.trim();
      _hasSufficientAllowance = data['hasSufficientAllowance'] == true;
    } catch (error) {
      _allowanceRaw = null;
      _hasSufficientAllowance = false;
      _errorMessage = _extractMessage(
        error,
        fallback: 'Failed to check token allowance',
      );
    }

    _isCheckingAllowance = false;
    notifyListeners();
  }

  void _clearQuote() {
    _quote = null;
    _quoteRaw = null;
    _fee = null;
    _priceImpact = null;
  }

  String _applySlippage(String amountRaw) {
    final raw = BigInt.parse(amountRaw);
    final minAmount =
        (raw * BigInt.from(10000 - _defaultSlippageBps)) ~/ BigInt.from(10000);
    return minAmount > BigInt.zero ? minAmount.toString() : '1';
  }

  void _recordLocalSwap({
    required String txHash,
    required String walletAddress,
    required String amountIn,
    required String estimatedOutput,
  }) {
    _mergeRecentSwaps([
      {
        'txHash': txHash,
        'wallet': walletAddress,
        'fromToken': _fromToken,
        'toToken': _toToken,
        'amountIn': amountIn,
        'estimatedOutput': estimatedOutput,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'submitted',
      },
    ]);
  }

  void _mergeRecentSwaps(List<Map<String, dynamic>> swaps) {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...swaps, ..._recentSwaps]) {
      final txHash = (item['txHash'] as String?)?.trim();
      final key = txHash != null && txHash.isNotEmpty
          ? txHash
          : '${item['timestamp']}-${item['fromToken']}-${item['toToken']}';
      merged.putIfAbsent(key, () => item);
    }

    _recentSwaps
      ..clear()
      ..addAll(merged.values)
      ..sort((left, right) {
        final leftTs = (left['timestamp'] as num?)?.toInt() ?? 0;
        final rightTs = (right['timestamp'] as num?)?.toInt() ?? 0;
        return rightTs.compareTo(leftTs);
      });
  }

  String _extractMessage(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is List && message.isNotEmpty) {
          return message.join(', ');
        }
        return message.toString();
      }
      if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    }

    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message.isNotEmpty ? message : fallback;
  }
}
