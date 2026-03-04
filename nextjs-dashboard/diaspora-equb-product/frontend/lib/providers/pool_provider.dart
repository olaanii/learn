import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
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
      debugPrint('[PoolProvider] loadPools: ${_pools.length} pools loaded');
      for (final p in _pools) {
        debugPrint('[PoolProvider]   id=${p['id']}, onChainPoolId=${p['onChainPoolId']}, status=${p['status']}, tier=${p['tier']}');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('Unauthorized')) {
        _errorMessage = 'Session expired — please log in again';
      } else if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        _errorMessage = 'Cannot reach server — check if backend is running';
      } else {
        _errorMessage = 'Failed to load equbs: ${msg.length > 80 ? msg.substring(0, 80) : msg}';
      }
      debugPrint('[PoolProvider] loadPools ERROR: $e');
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
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // 3. Wait for tx to be mined and create pool with onChainPoolId (active) immediately
      try {
        await _api.createPoolFromCreationTx(txHash);
        await loadPools();
      } catch (e) {
        _errorMessage =
            _apiErrorMessage(e, 'Pool created on-chain but failed to register');
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = _apiErrorMessage(e, 'Failed to create pool');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Extract user-facing message from API (e.g. 400) or wallet errors.
  static String _apiErrorMessage(Object e, String fallback) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        return msg is String ? msg : msg.toString();
      }
    }
    return '$fallback: $e';
  }

  static String _apiErrorCode(Object e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['code'] != null) {
        return data['code'].toString();
      }
    }
    return 'UNKNOWN_ERROR';
  }

  static String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  Future<Map<String, dynamic>?> closeActiveRound(String poolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.closeActiveRound(poolId);
      _selectedPool = await _api.getPool(poolId);
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _errorMessage = _apiErrorMessage(e, 'Failed to close active round');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<List<String>> getEligibleWinners(String poolId) async {
    try {
      final data = await _api.getEligibleWinners(poolId);
      final list = data['eligible'] as List? ?? [];
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[PoolProvider] getEligibleWinners error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> pickWinnerForActiveRound(String poolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.pickWinnerForActiveRound(
        poolId: poolId,
        idempotencyKey: _newIdempotencyKey(),
      );
      _selectedPool = await _api.getPool(poolId);
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      final code = _apiErrorCode(e);
      final defaultMessage = _apiErrorMessage(e, 'Failed to pick winner');
      _errorMessage = switch (code) {
        'WINNER_BEFORE_CLOSE' =>
          'Close the active round before picking the winner.',
        'ROUND_ALREADY_PICKED' =>
          'Winner is already picked for this round.',
        'SEASON_COMPLETE' =>
          'Season is complete. Configure next season to continue.',
        'NOT_POOL_ADMIN' =>
          'Only the pool admin can pick a winner.',
        'IDEMPOTENCY_REPLAY_CONFLICT' =>
          'Duplicate request conflict detected. Retry once.',
        _ => defaultMessage,
      };
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Build a join-pool TX from the backend, then sign & send via WalletConnect.
  /// Refreshes pool list on success so UI updates in real time.
  Future<String?> buildAndSignJoinPool(
    int onChainPoolId, {
    String? caller,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      debugPrint('[PoolProvider] buildAndSignJoinPool: poolId=$onChainPoolId, caller=$caller, walletAddr=${_walletService.walletAddress}');
      final unsignedTx = await _api.buildJoinPool(
        onChainPoolId,
        caller: caller,
      );
      debugPrint('[PoolProvider] Join unsigned TX: to=${unsignedTx['to']}, value=${unsignedTx['value']}, chainId=${unsignedTx['chainId']}');
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      debugPrint('[PoolProvider] Join result: txHash=$txHash, error=${_walletService.errorMessage}');

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
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
      debugPrint('[PoolProvider] buildAndSignContribute: poolId=$onChainPoolId, amount=$contributionAmount, token=$tokenAddress');
      final unsignedTx = await _api.buildContribute(
        onChainPoolId: onChainPoolId,
        contributionAmount: contributionAmount,
        tokenAddress: tokenAddress,
      );
      debugPrint('[PoolProvider] Got unsigned TX: to=${unsignedTx['to']}, value=${unsignedTx['value']}, gas=${unsignedTx['estimatedGas']}, chainId=${unsignedTx['chainId']}');
      debugPrint('[PoolProvider] Wallet connected: ${_walletService.isConnected}, addr: ${_walletService.walletAddress}');

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;
      debugPrint('[PoolProvider] signAndSend result: txHash=$txHash, error=${_walletService.errorMessage}');

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected by wallet';
      } else if (poolId != null) {
        await loadPool(poolId);
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      debugPrint('[PoolProvider] buildAndSignContribute ERROR: $e');
      _errorMessage = _apiErrorMessage(e, 'Failed to contribute');
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
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Approval rejected';
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
      final unsignedTx = await _api.buildCloseRound(onChainPoolId);
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
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
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
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

  /// Pool-creator action: close round then schedule payout for chain-selected winner.
  ///
  /// Backend may return `scheduleTx` immediately or only after close-round is mined.
  /// In the delayed case this method polls briefly, then asks the user to retry if
  /// schedule transaction is still not available.
  Future<Map<String, dynamic>?> buildAndSignSelectWinner({
    required String poolId,
    required String total,
    required int upfrontPercent,
    required int totalRounds,
    required String caller,
    void Function(String message)? onProgress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final payload = await _api.buildSelectWinner(
        poolId: poolId,
        phase: 'close',
        total: total,
        upfrontPercent: upfrontPercent,
        totalRounds: totalRounds,
        caller: caller,
      );

      final closeTx = Map<String, dynamic>.from(payload['closeTx'] as Map);
      Map<String, dynamic>? scheduleTx;
      if (payload['scheduleTx'] is Map) {
        scheduleTx = Map<String, dynamic>.from(payload['scheduleTx'] as Map);
      }
      String? winner = payload['winner']?.toString();
      final round = payload['round'];
      String? nextAction = payload['nextAction']?.toString();
      String? warning = payload['warning']?.toString();

      final closeHash = await _walletService.signAndSendTransaction(closeTx);
      if (closeHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Close round transaction rejected';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      onProgress?.call(
          'Round closed on-chain. Fetching winner and payout transaction...');

      final shouldSkipPolling =
          (nextAction?.contains('upgrade_contract') ?? false) ||
              (warning?.isNotEmpty ?? false);

      if (scheduleTx == null && !shouldSkipPolling) {
        for (int attempt = 0; attempt < 3; attempt++) {
          await Future.delayed(const Duration(seconds: 2));

          final followUp = await _api.buildSelectWinner(
            poolId: poolId,
            phase: 'schedule',
            total: total,
            upfrontPercent: upfrontPercent,
            totalRounds: totalRounds,
            caller: caller,
          );

          winner ??= followUp['winner']?.toString();
          nextAction = followUp['nextAction']?.toString() ?? nextAction;
          warning = followUp['warning']?.toString() ?? warning;

          if (followUp['scheduleTx'] is Map) {
            scheduleTx =
                Map<String, dynamic>.from(followUp['scheduleTx'] as Map);
            break;
          }
        }
      }

      if (scheduleTx == null) {
        _lastTxHash = closeHash;
        _errorMessage = (nextAction?.contains('upgrade_contract') ?? false)
            ? (warning ??
                'Round closed, but this deployed contract cannot expose winner view methods. Scheduling requires upgraded contract support.')
            : 'Round closed. Winner is being finalized on-chain. Please retry Select Winner in a few seconds.';
        _isLoading = false;
        notifyListeners();
        return {
          'closeTxHash': closeHash,
          'scheduleTxHash': null,
          'winner': winner,
          'round': round,
          'nextAction': nextAction ?? 'await_schedule_tx',
          'warning': warning,
        };
      }

      onProgress
          ?.call('Winner ready. Confirm payout scheduling in your wallet...');

      final scheduleHash =
          await _walletService.signAndSendTransaction(scheduleTx);
      if (scheduleHash == null) {
        _errorMessage = _walletService.errorMessage ??
            'Schedule payout transaction rejected';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _lastTxHash = scheduleHash;
      _isLoading = false;
      notifyListeners();

      return {
        'closeTxHash': closeHash,
        'scheduleTxHash': scheduleHash,
        'winner': winner,
        'round': round,
        'nextAction': nextAction ?? 'done',
        'warning': warning,
      };
    } catch (e) {
      _errorMessage = _apiErrorMessage(e, 'Failed to auto-select winner');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  String _friendlyWinnerError(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map) {
      final data = e.response!.data as Map;
      final code = data['code']?.toString();
      final message = data['message']?.toString();
      switch (code) {
        case 'WINNER_BEFORE_CLOSE':
          return 'Close the active round first before picking a winner.';
        case 'ROUND_ALREADY_PICKED':
          return 'Winner is already picked for this round.';
        case 'SEASON_COMPLETE':
          return 'Season is complete. Configure the next season to continue.';
        case 'NOT_POOL_ADMIN':
          return 'Only the pool admin can pick the winner.';
        case 'IDEMPOTENCY_REPLAY_CONFLICT':
          return 'This winner request was already used with different details. Retry with a fresh attempt.';
      }
      if (message != null && message.isNotEmpty) return message;
    }
    return _apiErrorMessage(e, fallback);
  }

  Future<Map<String, dynamic>?> pickWinnerAutoFromClosedRound({
    required String poolId,
    required String total,
    required int upfrontPercent,
    required int totalRounds,
    required String caller,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final payload = await _api.buildSelectWinner(
        poolId: poolId,
        phase: 'schedule',
        total: total,
        upfrontPercent: upfrontPercent,
        totalRounds: totalRounds,
        caller: caller,
      );

      if (payload['scheduleTx'] is! Map) {
        _errorMessage = payload['warning']?.toString() ??
            'Winner is not ready yet. Ensure the round is closed and try again.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final scheduleTx = Map<String, dynamic>.from(payload['scheduleTx'] as Map);
      final txHash = await _walletService.signAndSendTransaction(scheduleTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Transaction rejected';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      await loadPool(poolId);
      _isLoading = false;
      notifyListeners();

      return {
        'scheduleTxHash': txHash,
        'winner': payload['winner']?.toString(),
        'round': payload['round'],
      };
    } catch (e) {
      _errorMessage = _friendlyWinnerError(e, 'Failed to pick winner');
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
      _errorMessage = _apiErrorMessage(e, 'Failed to create pool');
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createNextSeason({
    required String poolId,
    required String caller,
    String? contributionAmount,
    String? token,
    int? payoutSplitPct,
    String? cadence,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.createNextSeason(
        poolId: poolId,
        caller: caller,
        contributionAmount: contributionAmount,
        token: token,
        payoutSplitPct: payoutSplitPct,
        cadence: cadence,
      );

      await loadPool(poolId);
      await loadPools();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = _apiErrorMessage(e, 'Failed to create next season');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
