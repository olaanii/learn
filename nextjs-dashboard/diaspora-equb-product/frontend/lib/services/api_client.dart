import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'jwt_token';

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Prevent browser 304 caching on Flutter web
        options.headers['Cache-Control'] = 'no-cache';
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired -- clear and redirect to login
          _storage.delete(key: _tokenKey);
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  // ── Auth ──────────────────────────────────────
  Future<Map<String, dynamic>> firebaseSession(String idToken) async {
    final response = await _dio.post('auth/firebase/session', data: {
      'idToken': idToken,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> verifyFayda(String token) async {
    try {
      final response =
          await _dio.post('auth/fayda/verify', data: {'token': token});
      return response.data;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            'DIO EXCEPTION in verifyFayda: ${e.response?.statusCode} ${e.response?.data} | url: ${e.requestOptions.uri}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> walletChallenge(String walletAddress) async {
    try {
      final response = await _dio.post('auth/wallet/challenge', data: {
        'walletAddress': walletAddress,
      });
      return response.data;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            'DIO EXCEPTION in walletChallenge: ${e.response?.statusCode} ${e.response?.data} | url: ${e.requestOptions.uri}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> walletVerify({
    required String walletAddress,
    required String signature,
    required String message,
  }) async {
    try {
      final response = await _dio.post('auth/wallet/verify', data: {
        'walletAddress': walletAddress,
        'signature': signature,
        'message': message,
      });
      return response.data;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            'DIO EXCEPTION in walletVerify: ${e.response?.statusCode} ${e.response?.data} | url: ${e.requestOptions.uri}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> devLogin({String? walletAddress}) async {
    try {
      final response = await _dio.post('auth/dev-login', data: {
        if (walletAddress != null) 'walletAddress': walletAddress,
      });
      return response.data;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            'DIO EXCEPTION in devLogin: ${e.response?.statusCode} ${e.response?.data} | url: ${e.requestOptions.uri}');
      }
      rethrow;
    }
  }

  // ── Security ──────────────────────────────────
  Future<Map<String, dynamic>> get2FAStatus() async {
    final response = await _dio.get('security/2fa/status');
    return response.data;
  }

  Future<Map<String, dynamic>> setup2FA() async {
    final response = await _dio.post('security/2fa/setup');
    return response.data;
  }

  Future<Map<String, dynamic>> verify2FA(String code) async {
    final response = await _dio.post('security/2fa/verify', data: {
      'code': code,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> disable2FA() async {
    final response = await _dio.delete('security/2fa');
    return response.data;
  }

  Future<List<dynamic>> listTrustedDevices() async {
    final response = await _dio.get('security/devices');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> registerTrustedDevice({
    required String fingerprint,
    String? userAgent,
  }) async {
    final response = await _dio.post('security/devices/register', data: {
      'fingerprint': fingerprint,
      if (userAgent != null && userAgent.isNotEmpty) 'userAgent': userAgent,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> revokeTrustedDevice(String deviceId) async {
    final response = await _dio.delete('security/devices/$deviceId');
    return response.data;
  }

  // ── Identity ──────────────────────────────────
  Future<Map<String, dynamic>> bindWalletChallenge(
      String identityHash, String walletAddress) async {
    final response = await _dio.post('wallet/bind/challenge', data: {
      'identityHash': identityHash,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> bindWalletVerify({
    required String identityHash,
    required String walletAddress,
    required String message,
    required String signature,
  }) async {
    final response = await _dio.post('wallet/bind/verify', data: {
      'identityHash': identityHash,
      'walletAddress': walletAddress,
      'message': message,
      'signature': signature,
    });
    return response.data;
  }

  // ── Tiers ─────────────────────────────────────
  Future<Map<String, dynamic>> getTierEligibility(String walletAddress) async {
    final response = await _dio.get('tiers/eligibility', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<List<dynamic>> getAllTiers() async {
    final response = await _dio.get('tiers');
    return response.data;
  }

  // ── Pools ─────────────────────────────────────
  Future<List<dynamic>> listPools({int? tier}) async {
    final response = await _dio.get('pools', queryParameters: {
      if (tier != null) 'tier': tier,
      '_t': DateTime.now().millisecondsSinceEpoch,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getPool(String poolId) async {
    final response = await _dio.get('pools/$poolId');
    return response.data;
  }

  /// Get token info for a pool (ERC-20 vs native CTC).
  Future<Map<String, dynamic>> getPoolToken(String poolId) async {
    final response = await _dio.get('pools/$poolId/token');
    return response.data;
  }

  Future<Map<String, dynamic>> createPool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    final response = await _dio.post('pools/create', data: {
      'tier': tier,
      'contributionAmount': contributionAmount,
      'maxMembers': maxMembers,
      'treasury': treasury,
      if (token != null) 'token': token,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> joinPool(
      String poolId, String walletAddress) async {
    final response = await _dio.post('pools/join', data: {
      'poolId': poolId,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> recordContribution(
      String poolId, String walletAddress, int round) async {
    final response = await _dio.post('pools/contributions', data: {
      'poolId': poolId,
      'walletAddress': walletAddress,
      'round': round,
    });
    return response.data;
  }

  // ── Pool TX Builders (non-custodial) ──────────
  Future<Map<String, dynamic>> buildCreatePool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    final response = await _dio.post('pools/build/create', data: {
      'tier': tier,
      'contributionAmount': contributionAmount,
      'maxMembers': maxMembers,
      'treasury': treasury,
      if (token != null) 'token': token,
    });
    return response.data;
  }

  /// Create pool from mined createPool tx. Backend waits for receipt and creates pool with onChainPoolId (active).
  Future<Map<String, dynamic>> createPoolFromCreationTx(String txHash) async {
    final response = await _dio.post(
      'pools/from-creation-tx',
      data: {'txHash': txHash.trim()},
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> buildJoinPool(
    int onChainPoolId, {
    String? caller,
  }) async {
    final response = await _dio.post('pools/build/join', data: {
      'onChainPoolId': onChainPoolId,
      if (caller != null) 'caller': caller,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildContribute({
    required int onChainPoolId,
    required String contributionAmount,
    String? tokenAddress,
  }) async {
    final response = await _dio.post('pools/build/contribute', data: {
      'onChainPoolId': onChainPoolId,
      'contributionAmount': contributionAmount,
      if (tokenAddress != null) 'tokenAddress': tokenAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildCloseRound(int onChainPoolId) async {
    final response = await _dio.post('pools/build/close-round', data: {
      'onChainPoolId': onChainPoolId,
    });
    return response.data;
  }

  /// Build approve TX so EqubPool can spend ERC-20 tokens on user's behalf.
  /// Must be signed before contributing to an ERC-20 pool.
  Future<Map<String, dynamic>> buildApproveToken({
    required String tokenAddress,
    required String amount,
  }) async {
    final response = await _dio.post('pools/build/approve-token', data: {
      'tokenAddress': tokenAddress,
      'amount': amount,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildScheduleStream({
    required int onChainPoolId,
    required String beneficiary,
    required String total,
    required int upfrontPercent,
    required int totalRounds,
  }) async {
    final response = await _dio.post('pools/build/schedule-stream', data: {
      'onChainPoolId': onChainPoolId,
      'beneficiary': beneficiary,
      'total': total,
      'upfrontPercent': upfrontPercent,
      'totalRounds': totalRounds,
    });
    return response.data;
  }

  /// Build unsigned TXs for close-round + rotating-winner payout scheduling.
  /// Winner is auto-selected by backend according to Equb rotation rules.
  Future<Map<String, dynamic>> buildSelectWinner({
    required String poolId,
    required String total,
    required int upfrontPercent,
    required int totalRounds,
    required String caller,
    String phase = 'auto',
  }) async {
    final response = await _dio.post('pools/$poolId/select-winner', data: {
      'phase': phase,
      'total': total,
      'upfrontPercent': upfrontPercent,
      'totalRounds': totalRounds,
      'caller': caller,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getEligibleWinners(String poolId) async {
    final response =
        await _dio.get('pools/$poolId/rounds/active/eligible-winners');
    return response.data;
  }

  Future<Map<String, dynamic>> closeActiveRound(String poolId) async {
    final response = await _dio.post('pools/$poolId/rounds/active/close');
    return response.data;
  }

  Future<Map<String, dynamic>> pickWinnerForActiveRound({
    required String poolId,
    required String idempotencyKey,
    String mode = 'auto',
  }) async {
    final response = await _dio.post(
      'pools/$poolId/rounds/active/pick-winner',
      data: {
        'mode': mode,
      },
      options: Options(
        headers: {
          'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> createNextSeason({
    required String poolId,
    required String caller,
    String? contributionAmount,
    String? token,
    int? payoutSplitPct,
    String? cadence,
  }) async {
    final response = await _dio.post('pools/$poolId/seasons', data: {
      'caller': caller,
      if (contributionAmount != null && contributionAmount.isNotEmpty)
        'contributionAmount': contributionAmount,
      if (token != null && token.isNotEmpty) 'token': token,
      if (payoutSplitPct != null) 'payoutSplitPct': payoutSplitPct,
      if (cadence != null && cadence.isNotEmpty) 'cadence': cadence,
    });
    return response.data;
  }

  // ── Collateral TX Builders ──────────────────────

  /// Build unsigned CTC collateral deposit TX (native).
  Future<Map<String, dynamic>> buildDepositCollateral(String amount) async {
    final response = await _dio.post('collateral/build/deposit', data: {
      'amount': amount,
    });
    return response.data;
  }

  /// Build unsigned CTC collateral release TX (native).
  Future<Map<String, dynamic>> buildReleaseCollateral({
    required String userAddress,
    required String amount,
  }) async {
    final response = await _dio.post('collateral/build/release', data: {
      'userAddress': userAddress,
      'amount': amount,
    });
    return response.data;
  }

  /// Build unsigned ERC-20 transfer TX to deposit USDC/USDT as collateral.
  Future<Map<String, dynamic>> buildDepositCollateralToken({
    required String amount,
    String tokenSymbol = 'USDC',
  }) async {
    final response = await _dio.post('collateral/build/deposit-token', data: {
      'amount': amount,
      'tokenSymbol': tokenSymbol,
    });
    return response.data;
  }

  /// Confirm on-chain token deposit so the backend records it in DB.
  Future<Map<String, dynamic>> confirmCollateralTokenDeposit({
    required String walletAddress,
    required String amount,
    required String tokenSymbol,
    required String txHash,
  }) async {
    final response = await _dio.post('collateral/deposit-token/confirm', data: {
      'walletAddress': walletAddress,
      'amount': amount,
      'tokenSymbol': tokenSymbol,
      'txHash': txHash,
    });
    return response.data;
  }

  /// Release token collateral: deployer sends USDC/USDT back to user.
  Future<Map<String, dynamic>> releaseCollateralToken({
    required String walletAddress,
    required String amount,
    String tokenSymbol = 'USDC',
  }) async {
    final response = await _dio.post('collateral/release-token', data: {
      'walletAddress': walletAddress,
      'amount': amount,
      'tokenSymbol': tokenSymbol,
    });
    return response.data;
  }

  // ── Identity TX Builders ────────────────────────
  Future<Map<String, dynamic>> buildStoreOnChain({
    required String identityHash,
    required String walletAddress,
  }) async {
    final response = await _dio.post('wallet/build/store-onchain', data: {
      'identityHash': identityHash,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Credit ────────────────────────────────────
  Future<Map<String, dynamic>> getCreditScore(String walletAddress) async {
    final response = await _dio.get('credit', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Collateral ────────────────────────────────
  Future<List<dynamic>> getCollateral(String walletAddress) async {
    final response = await _dio.get('collateral', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> lockCollateral({
    required String walletAddress,
    required String amount,
    String? poolId,
  }) async {
    final response = await _dio.post('collateral/lock', data: {
      'walletAddress': walletAddress,
      'amount': amount,
      if (poolId != null) 'poolId': poolId,
    });
    return response.data;
  }

  // ── Token / Wallet ─────────────────────────────
  Future<Map<String, dynamic>> requestFaucet({
    required String walletAddress,
    double amount = 1000,
    String token = 'USDC',
  }) async {
    final response = await _dio.post('token/faucet', data: {
      'walletAddress': walletAddress,
      'amount': amount,
      'token': token,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTokenBalance(String walletAddress,
      {String token = 'USDC', String? tokenAddress}) async {
    final response = await _dio.get('token/balance', queryParameters: {
      'walletAddress': walletAddress,
      'token': token,
      if (tokenAddress != null) 'tokenAddress': tokenAddress,
    });
    return response.data;
  }

  Future<List<dynamic>> getTokenTransactions(
    String walletAddress, {
    String token = 'ALL',
    int limit = 50,
    int? fromTimestamp,
    int? toTimestamp,
    String? direction,
    String? status,
    String? cursor,
  }) async {
    final response = await _dio.get('token/transactions', queryParameters: {
      'walletAddress': walletAddress,
      'token': token,
      'limit': limit,
      if (fromTimestamp != null) 'fromTimestamp': fromTimestamp,
      if (toTimestamp != null) 'toTimestamp': toTimestamp,
      if (direction != null && direction.isNotEmpty) 'direction': direction,
      if (status != null && status.isNotEmpty) 'status': status,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    // Ensure we always return a list so UI doesn't break on unexpected shape
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> buildTransfer({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
  }) async {
    final response = await _dio.post('token/transfer', data: {
      'from': from,
      'to': to,
      'amount': amount,
      'token': token,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildWithdraw({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
    String network = 'ERC-20',
  }) async {
    final response = await _dio.post('token/withdraw', data: {
      'from': from,
      'to': to,
      'amount': amount,
      'token': token,
      'network': network,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getExchangeRates() async {
    final response = await _dio.get('token/rates');
    return response.data;
  }

  Future<List<dynamic>> getSupportedTokens() async {
    final response = await _dio.get('token/supported');
    return response.data;
  }

  Future<Map<String, dynamic>> getTokenAllowance({
    required String walletAddress,
    required String spender,
    required String token,
    String? tokenAddress,
    String? requiredAmountRaw,
  }) async {
    final response = await _dio.get(
      'token/allowance',
      queryParameters: {
        'walletAddress': walletAddress,
        'spender': spender,
        'token': token,
        if (tokenAddress != null && tokenAddress.isNotEmpty)
          'tokenAddress': tokenAddress,
        if (requiredAmountRaw != null && requiredAmountRaw.isNotEmpty)
          'requiredAmountRaw': requiredAmountRaw,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── Equb Rules ──────────────────────────────
  Future<Map<String, dynamic>> getEqubRules(String poolId) async {
    final response = await _dio.get('pools/$poolId/rules');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateEqubRules({
    required String poolId,
    required Map<String, dynamic> rules,
  }) async {
    final response = await _dio.patch('pools/$poolId/rules', data: rules);
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── Equb Insights ────────────────────────────
  Future<Map<String, dynamic>> getEqubPopularSeries({
    int? from,
    int? to,
    String? token,
    String? status,
    String? metric,
    int? limit,
    int? offset,
    String bucket = 'day',
  }) async {
    final response = await _dio.get(
      'analytics/equbs/popular-series',
      queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (token != null && token.isNotEmpty && token != 'all') 'token': token,
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        if (metric != null && metric.isNotEmpty) 'metric': metric,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        'bucket': bucket,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getEqubJoinedProgress({
    required String wallet,
    int? from,
    int? to,
    String? token,
    String? status,
    String bucket = 'day',
  }) async {
    final response = await _dio.get(
      'analytics/equbs/joined-progress',
      queryParameters: {
        'wallet': wallet,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (token != null && token.isNotEmpty && token != 'all') 'token': token,
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        'bucket': bucket,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getEqubSummary({
    required String wallet,
    int? from,
    int? to,
    String? token,
    String? status,
  }) async {
    final response = await _dio.get(
      'analytics/equbs/summary',
      queryParameters: {
        'wallet': wallet,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (token != null && token.isNotEmpty && token != 'all') 'token': token,
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getEqubGlobalStats({int? type}) async {
    final response = await _dio.get(
      'analytics/equbs/global-stats',
      queryParameters: {
        if (type != null) 'type': type,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getEqubTrending() async {
    final response = await _dio.get('analytics/equbs/trending');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> getEqubLeaderboard({
    int? type,
    String? sort,
    int? page,
    int? limit,
  }) async {
    final response = await _dio.get(
      'analytics/equbs/leaderboard',
      queryParameters: {
        if (type != null) 'type': type,
        if (sort != null) 'sort': sort,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      },
    );
    return response.data;
  }

  // ── Notifications ──────────────────────────────
  Future<List<dynamic>> getNotifications(
      {int limit = 50, int offset = 0}) async {
    final response = await _dio.get('notifications', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _dio.get('notifications/unread-count');
    return response.data['count'] ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.patch('notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch('notifications/read-all');
  }

  Future<Map<String, dynamic>> getNotificationsIncremental({
    String? afterCreatedAt,
    String? afterId,
    int limit = 50,
  }) async {
    final response =
        await _dio.get('notifications/incremental', queryParameters: {
      if (afterCreatedAt != null && afterCreatedAt.isNotEmpty)
        'afterCreatedAt': afterCreatedAt,
      if (afterId != null && afterId.isNotEmpty) 'afterId': afterId,
      'limit': limit,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Stream<String>> openNotificationEventStream() async {
    final response = await _dio.get<ResponseBody>(
      'notifications/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    final body = response.data;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Notification stream unavailable',
      );
    }

    return body.stream
        .map<List<int>>((chunk) => chunk)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  // ── Governance ────────────────────────────────
  Future<List<dynamic>> getProposals(String poolId) async {
    final response = await _dio.get('pools/$poolId/proposals');
    return response.data;
  }

  Future<Map<String, dynamic>> getProposal(
      String poolId, String proposalId) async {
    final response = await _dio.get('pools/$poolId/proposals/$proposalId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buildProposeTx({
    required String poolId,
    required Map<String, dynamic> rules,
    required String description,
    required String callerAddress,
  }) async {
    final response = await _dio.post('pools/$poolId/proposals', data: {
      'rules': rules,
      'description': description,
      'callerAddress': callerAddress,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buildVoteTx({
    required String poolId,
    required int onChainProposalId,
    required bool support,
    required String callerAddress,
  }) async {
    final response = await _dio.post(
      'pools/$poolId/proposals/$onChainProposalId/vote',
      data: {'support': support, 'callerAddress': callerAddress},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buildExecuteTx({
    required String poolId,
    required int onChainProposalId,
    required String callerAddress,
  }) async {
    final response = await _dio.post(
      'pools/$poolId/proposals/$onChainProposalId/execute',
      data: {'callerAddress': callerAddress},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── Referral ──────────────────────────────────
  Future<Map<String, dynamic>> getReferralCode() async {
    final response = await _dio.get('referral/code');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final response = await _dio.get('referral/stats');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> getReferralCommissions() async {
    final response = await _dio.get('referral/commissions');
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  // ── Swap ──────────────────────────────────────
  Future<Map<String, dynamic>> getSwapQuote({
    required String fromToken,
    required String toToken,
    required String amountIn,
  }) async {
    final response = await _dio.post('swap/quote', data: {
      'fromToken': fromToken,
      'toToken': toToken,
      'amountIn': amountIn,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buildSwapTx({
    required String fromToken,
    required String toToken,
    required String amountInRaw,
    required String minAmountOutRaw,
  }) async {
    final response = await _dio.post('swap/build-tx', data: {
      'fromToken': fromToken,
      'toToken': toToken,
      'amountInRaw': amountInRaw,
      'minAmountOutRaw': minAmountOutRaw,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buildSwapApprovalTx({
    required String fromToken,
    required String amountInRaw,
  }) async {
    final response = await _dio.post('swap/build-approval', data: {
      'fromToken': fromToken,
      'amountInRaw': amountInRaw,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getSwapStatus() async {
    final response = await _dio.get('swap/status');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> getSwapHistory({String? wallet}) async {
    final response = await _dio.get(
      'swap/history',
      queryParameters: {
        if (wallet != null && wallet.isNotEmpty) 'wallet': wallet,
      },
    );
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  // ── Health ────────────────────────────────────
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('health');
    return response.data;
  }
}
