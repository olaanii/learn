import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class CreditProvider extends ChangeNotifier {
  final ApiClient _api;

  int _score = 0;
  int _eligibleTier = 0;
  int _collateralRate = 0;
  String _maxPoolSize = '0';
  int? _nextTier;
  int? _scoreForNextTier;
  bool _isLoading = false;
  String? _errorMessage;

  CreditProvider(this._api);

  int get score => _score;
  int get eligibleTier => _eligibleTier;
  int get collateralRate => _collateralRate;
  String get maxPoolSize => _maxPoolSize;
  int? get nextTier => _nextTier;
  int? get scoreForNextTier => _scoreForNextTier;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCreditScore(String walletAddress) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getCreditScore(walletAddress);
      _score = data['score'] ?? 0;
    } catch (e) {
      _errorMessage = 'Failed to load credit score';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTierEligibility(String walletAddress) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getTierEligibility(walletAddress);
      _score = data['creditScore'] ?? 0;
      _eligibleTier = data['eligibleTier'] ?? 0;
      _collateralRate = data['collateralRate'] ?? 0;
      _maxPoolSize = data['maxPoolSize'] ?? '0';
      _nextTier = data['nextTier'];
      _scoreForNextTier = data['scoreForNextTier'];
    } catch (e) {
      _errorMessage = 'Failed to load tier eligibility';
    }

    _isLoading = false;
    notifyListeners();
  }
}
