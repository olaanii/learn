import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';

class CollateralProvider extends ChangeNotifier {
  final ApiClient _api;
  final WalletService _walletService;

  List<Map<String, dynamic>> _collaterals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastTxHash;

  CollateralProvider(this._api, this._walletService);

  List<Map<String, dynamic>> get collaterals => _collaterals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastTxHash => _lastTxHash;

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

  // ─── On-Chain TX Builder Methods (WalletConnect signing) ────────────────────

  /// Build unsigned TX to deposit collateral, then sign & send via WalletConnect.
  /// Returns the TX hash on success, or null on failure.
  /// Pass [walletAddress] to refresh collateral data after success.
  Future<String?> buildAndSignDeposit(String amount, {String? walletAddress}) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      // 1. Get unsigned TX from backend
      final unsignedTx = await _api.buildDepositCollateral(amount);

      // 2. Sign and send via WalletConnect
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      } else if (walletAddress != null) {
        await loadCollateral(walletAddress);
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to deposit collateral: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build unsigned TX to release collateral, then sign & send via WalletConnect.
  Future<String?> buildAndSignRelease({
    required String userAddress,
    required String amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildReleaseCollateral(
        userAddress: userAddress,
        amount: amount,
      );

      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      } else {
        await loadCollateral(userAddress);
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to release collateral: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Legacy DB Methods (kept for dev/test without WalletConnect) ────────────

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
