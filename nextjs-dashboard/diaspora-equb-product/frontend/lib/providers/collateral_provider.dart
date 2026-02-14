import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class CollateralProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Map<String, dynamic>> _collaterals = [];
  bool _isLoading = false;
  String? _errorMessage;

  CollateralProvider(this._api);

  List<Map<String, dynamic>> get collaterals => _collaterals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Total locked amount across all collateral entries.
  double get totalLocked {
    double total = 0;
    for (final c in _collaterals) {
      total += double.tryParse(c['lockedAmount']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  /// Total slashed amount across all collateral entries.
  double get totalSlashed {
    double total = 0;
    for (final c in _collaterals) {
      total += double.tryParse(c['slashedAmount']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  /// Total available balance across all collateral entries.
  double get totalAvailable {
    double total = 0;
    for (final c in _collaterals) {
      total += double.tryParse(c['availableBalance']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  Future<void> loadCollateral(String walletAddress) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getCollateral(walletAddress);
      _collaterals = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _errorMessage = 'Failed to load collateral';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> lockCollateral({
    required String walletAddress,
    required String amount,
    String? poolId,
  }) async {
    try {
      await _api.lockCollateral(
        walletAddress: walletAddress,
        amount: amount,
        poolId: poolId,
      );
      // Reload collateral data
      await loadCollateral(walletAddress);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to lock collateral';
      notifyListeners();
      return false;
    }
  }
}
