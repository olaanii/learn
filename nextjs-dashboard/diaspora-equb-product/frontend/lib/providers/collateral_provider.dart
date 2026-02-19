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

  double get totalLocked {
    double total = 0;
    for (final c in _collaterals) {
      total += double.tryParse(c['lockedAmount']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  double get totalSlashed {
    double total = 0;
    for (final c in _collaterals) {
      total += double.tryParse(c['slashedAmount']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

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

  // ─── ERC-20 Token Collateral (USDC / USDT) ────────────────────────────────

  /// Deposit USDC/USDT as collateral:
  /// 1. Backend builds ERC-20 transfer TX -> user signs via MetaMask
  /// 2. After TX confirmed, backend records it in DB
  Future<String?> buildAndSignDepositToken({
    required String amount,
    required String walletAddress,
    String tokenSymbol = 'USDC',
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

      final unsignedTx = await _api.buildDepositCollateralToken(
        amount: amount,
        tokenSymbol: tokenSymbol,
      );

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _optimisticAddLocked(double.tryParse(amount) ?? 0);

      try {
        await _api.confirmCollateralTokenDeposit(
          walletAddress: walletAddress,
          amount: amount,
          tokenSymbol: tokenSymbol,
          txHash: txHash,
        );
      } catch (_) {
        // Non-fatal: deposit is already on-chain
      }

      await loadCollateral(walletAddress);
      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Token collateral deposit failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Release token collateral: backend (deployer) sends tokens back to user.
  Future<String?> releaseTokenCollateral({
    required String walletAddress,
    required String amount,
    String tokenSymbol = 'USDC',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final result = await _api.releaseCollateralToken(
        walletAddress: walletAddress,
        amount: amount,
        tokenSymbol: tokenSymbol,
      );

      final txHash = result['txHash'] as String?;
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = 'Release failed — no transaction hash returned';
      }

      await loadCollateral(walletAddress);
      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Token collateral release failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void _optimisticAddLocked(double amount) {
    if (_collaterals.isEmpty) {
      _collaterals = [
        {
          'lockedAmount': amount.toString(),
          'availableBalance': '0',
          'slashedAmount': '0',
          'source': 'token',
        }
      ];
    } else {
      final updated = List<Map<String, dynamic>>.from(_collaterals);
      final c = Map<String, dynamic>.from(updated[0]);
      final cur = double.tryParse(c['lockedAmount']?.toString() ?? '0') ?? 0;
      c['lockedAmount'] = (cur + amount).toString();
      updated[0] = c;
      _collaterals = updated;
    }
    notifyListeners();
  }

  // ─── Native CTC Collateral (backward compat) ──────────────────────────────

  Future<String?> buildAndSignDeposit(String amount, {String? walletAddress}) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildDepositCollateral(amount);
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
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

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.lockCollateral(
        walletAddress: walletAddress,
        amount: amount,
        poolId: poolId,
      );
      final addAmount = double.tryParse(amount) ?? 0;
      if (addAmount > 0 && _collaterals.isNotEmpty) {
        final updated = List<Map<String, dynamic>>.from(_collaterals);
        for (var i = 0; i < updated.length; i++) {
          final c = Map<String, dynamic>.from(updated[i]);
          final cur = double.tryParse(c['lockedAmount']?.toString() ?? '0') ?? 0;
          c['lockedAmount'] = (cur + addAmount).toString();
          updated[i] = c;
        }
        _collaterals = updated;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      await loadCollateral(walletAddress);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to lock collateral';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
