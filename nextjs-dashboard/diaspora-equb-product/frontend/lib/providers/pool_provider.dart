import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';

class PoolProvider extends ChangeNotifier {
  final ApiClient _api;
  final WalletService _walletService;

  List<Map<String, dynamic>> _pools = [];
  Map<String, dynamic>? _selectedPool;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastTxHash;

  PoolProvider(this._api, this._walletService);

  List<Map<String, dynamic>> get pools => _pools;
  Map<String, dynamic>? get selectedPool => _selectedPool;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastTxHash => _lastTxHash;

  // ─── Token Helpers (for ERC-20 pool detection) ──────────────────────────────

  /// Query whether a pool uses an ERC-20 token and return its details.
  /// Returns null on error. Check `isErc20` in the result map.
  Future<Map<String, dynamic>?> getPoolTokenInfo(String poolId) async {
    try {
      return await _api.getPoolToken(poolId);
    } catch (e) {
      _errorMessage = 'Failed to get pool token info';
      notifyListeners();
      return null;
    }
  }

  // ─── Read Methods (from backend cache) ──────────────────────────────────────

  Future<void> loadPools({int? tier}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.listPools(tier: tier);
      _pools = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _errorMessage = 'Failed to load pools';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPool(String poolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedPool = await _api.getPool(poolId);
    } catch (e) {
      _errorMessage = 'Failed to load pool details';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── On-Chain TX Builder Methods (WalletConnect signing) ────────────────────

  /// Build a create-pool TX from the backend, then sign & send via WalletConnect.
  ///
  /// [token] - Optional ERC-20 token address for contributions.
  ///           Pass null or zero address for native CTC pools.
  Future<String?> buildAndSignCreatePool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      // 1. Get unsigned TX from backend
      final unsignedTx = await _api.buildCreatePool(
        tier: tier,
        contributionAmount: contributionAmount,
        maxMembers: maxMembers,
        treasury: treasury,
        token: token,
      );

      // 2. Sign and send via WalletConnect
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to create pool: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build a join-pool TX from the backend, then sign & send via WalletConnect.
  /// Refreshes pool list on success so UI updates in real time.
  Future<String?> buildAndSignJoinPool(int onChainPoolId) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildJoinPool(onChainPoolId);
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      } else {
        await loadPools();
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to join pool: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build a contribute TX from the backend, then sign & send via WalletConnect.
  ///
  /// For ERC-20 pools, pass [tokenAddress] so the backend returns value=0.
  /// The caller should ensure approval is done first via [buildAndSignApproveToken].
  /// Pass [poolId] to refresh pool detail on success so UI updates in real time.
  Future<String?> buildAndSignContribute(
    int onChainPoolId,
    String contributionAmount, {
    String? tokenAddress,
    String? poolId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildContribute(
        onChainPoolId: onChainPoolId,
        contributionAmount: contributionAmount,
        tokenAddress: tokenAddress,
      );
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      } else if (poolId != null) {
        await loadPool(poolId);
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to contribute: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build an ERC-20 approve TX and sign via WalletConnect.
  /// Must be signed BEFORE contributing to an ERC-20 pool.
  Future<String?> buildAndSignApproveToken({
    required String tokenAddress,
    required String amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildApproveToken(
        tokenAddress: tokenAddress,
        amount: amount,
      );
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Approval rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to approve token: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Convenience: approve + contribute in one flow for ERC-20 pools.
  /// Prompts the wallet twice: once for the approve, once for the contribute.
  Future<String?> approveAndContribute({
    required int onChainPoolId,
    required String contributionAmount,
    required String tokenAddress,
  }) async {
    // Step 1: Approve the EqubPool contract to spend the user's tokens
    final approveTxHash = await buildAndSignApproveToken(
      tokenAddress: tokenAddress,
      amount: contributionAmount,
    );
    if (approveTxHash == null) return null;

    // Step 2: Contribute to the pool
    return buildAndSignContribute(
      onChainPoolId,
      contributionAmount,
      tokenAddress: tokenAddress,
    );
  }

  /// Build a close-round TX from the backend, then sign & send via WalletConnect.
  Future<String?> buildAndSignCloseRound(int onChainPoolId) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx =
          await _api.buildCloseRound(onChainPoolId);
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to close round: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build a schedule-stream TX from the backend, then sign & send via WalletConnect.
  Future<String?> buildAndSignScheduleStream({
    required int onChainPoolId,
    required String beneficiary,
    required String total,
    required int upfrontPercent,
    required int totalRounds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildScheduleStream(
        onChainPoolId: onChainPoolId,
        beneficiary: beneficiary,
        total: total,
        upfrontPercent: upfrontPercent,
        totalRounds: totalRounds,
      );
      final txHash =
          await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Transaction rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to schedule stream: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Legacy DB Methods (kept for dev/test without WalletConnect) ────────────

  Future<bool> joinPool(String poolId, String walletAddress) async {
    try {
      await _api.joinPool(poolId, walletAddress);
      await loadPool(poolId);
      await loadPools();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to join pool';
      notifyListeners();
      return false;
    }
  }

  Future<bool> contribute(
      String poolId, String walletAddress, int round) async {
    try {
      await _api.recordContribution(poolId, walletAddress, round);
      await loadPool(poolId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to record contribution';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> createPool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    try {
      final pool = await _api.createPool(
        tier: tier,
        contributionAmount: contributionAmount,
        maxMembers: maxMembers,
        treasury: treasury,
        token: token,
      );
      await loadPools();
      return pool;
    } catch (e) {
      _errorMessage = 'Failed to create pool';
      notifyListeners();
      return null;
    }
  }
}
