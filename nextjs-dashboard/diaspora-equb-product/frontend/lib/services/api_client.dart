import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'jwt_token';

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
  Future<Map<String, dynamic>> verifyFayda(String token) async {
    final response =
        await _dio.post('/auth/fayda/verify', data: {'token': token});
    return response.data;
  }

  Future<Map<String, dynamic>> devLogin({String? walletAddress}) async {
    final response = await _dio.post('/auth/dev-login', data: {
      if (walletAddress != null) 'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Identity ──────────────────────────────────
  Future<Map<String, dynamic>> bindWallet(
      String identityHash, String walletAddress) async {
    final response = await _dio.post('/wallet/bind', data: {
      'identityHash': identityHash,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Tiers ─────────────────────────────────────
  Future<Map<String, dynamic>> getTierEligibility(String walletAddress) async {
    final response = await _dio.get('/tiers/eligibility', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<List<dynamic>> getAllTiers() async {
    final response = await _dio.get('/tiers');
    return response.data;
  }

  // ── Pools ─────────────────────────────────────
  Future<List<dynamic>> listPools({int? tier}) async {
    final response = await _dio.get('/pools', queryParameters: {
      if (tier != null) 'tier': tier,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getPool(String poolId) async {
    final response = await _dio.get('/pools/$poolId');
    return response.data;
  }

  /// Get token info for a pool (ERC-20 vs native CTC).
  Future<Map<String, dynamic>> getPoolToken(String poolId) async {
    final response = await _dio.get('/pools/$poolId/token');
    return response.data;
  }

  Future<Map<String, dynamic>> createPool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    final response = await _dio.post('/pools/create', data: {
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
    final response = await _dio.post('/pools/join', data: {
      'poolId': poolId,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> recordContribution(
      String poolId, String walletAddress, int round) async {
    final response = await _dio.post('/pools/contributions', data: {
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
    final response = await _dio.post('/pools/build/create', data: {
      'tier': tier,
      'contributionAmount': contributionAmount,
      'maxMembers': maxMembers,
      'treasury': treasury,
      if (token != null) 'token': token,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildJoinPool(int onChainPoolId) async {
    final response = await _dio.post('/pools/build/join', data: {
      'onChainPoolId': onChainPoolId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildContribute({
    required int onChainPoolId,
    required String contributionAmount,
    String? tokenAddress,
  }) async {
    final response = await _dio.post('/pools/build/contribute', data: {
      'onChainPoolId': onChainPoolId,
      'contributionAmount': contributionAmount,
      if (tokenAddress != null) 'tokenAddress': tokenAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildCloseRound(int onChainPoolId) async {
    final response = await _dio.post('/pools/build/close-round', data: {
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
    final response = await _dio.post('/pools/build/approve-token', data: {
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
    final response = await _dio.post('/pools/build/schedule-stream', data: {
      'onChainPoolId': onChainPoolId,
      'beneficiary': beneficiary,
      'total': total,
      'upfrontPercent': upfrontPercent,
      'totalRounds': totalRounds,
    });
    return response.data;
  }

  // ── Collateral TX Builders ──────────────────────
  Future<Map<String, dynamic>> buildDepositCollateral(String amount) async {
    final response = await _dio.post('/collateral/build/deposit', data: {
      'amount': amount,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildReleaseCollateral({
    required String userAddress,
    required String amount,
  }) async {
    final response = await _dio.post('/collateral/build/release', data: {
      'userAddress': userAddress,
      'amount': amount,
    });
    return response.data;
  }

  // ── Identity TX Builders ────────────────────────
  Future<Map<String, dynamic>> buildStoreOnChain({
    required String identityHash,
    required String walletAddress,
  }) async {
    final response = await _dio.post('/wallet/build/store-onchain', data: {
      'identityHash': identityHash,
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Credit ────────────────────────────────────
  Future<Map<String, dynamic>> getCreditScore(String walletAddress) async {
    final response = await _dio.get('/credit', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  // ── Collateral ────────────────────────────────
  Future<List<dynamic>> getCollateral(String walletAddress) async {
    final response = await _dio.get('/collateral', queryParameters: {
      'walletAddress': walletAddress,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> lockCollateral({
    required String walletAddress,
    required String amount,
    String? poolId,
  }) async {
    final response = await _dio.post('/collateral/lock', data: {
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
    final response = await _dio.post('/token/faucet', data: {
      'walletAddress': walletAddress,
      'amount': amount,
      'token': token,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTokenBalance(
      String walletAddress, {String token = 'USDC'}) async {
    final response = await _dio.get('/token/balance', queryParameters: {
      'walletAddress': walletAddress,
      'token': token,
    });
    return response.data;
  }

  Future<List<dynamic>> getTokenTransactions(
      String walletAddress, {String token = 'USDC', int limit = 20}) async {
    final response = await _dio.get('/token/transactions', queryParameters: {
      'walletAddress': walletAddress,
      'token': token,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> buildTransfer({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
  }) async {
    final response = await _dio.post('/token/transfer', data: {
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
    final response = await _dio.post('/token/withdraw', data: {
      'from': from,
      'to': to,
      'amount': amount,
      'token': token,
      'network': network,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getExchangeRates() async {
    final response = await _dio.get('/token/rates');
    return response.data;
  }

  Future<List<dynamic>> getSupportedTokens() async {
    final response = await _dio.get('/token/supported');
    return response.data;
  }

  // ── Health ────────────────────────────────────
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }
}
