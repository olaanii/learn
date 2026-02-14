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

  Future<Map<String, dynamic>> createPool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
  }) async {
    final response = await _dio.post('/pools/create', data: {
      'tier': tier,
      'contributionAmount': contributionAmount,
      'maxMembers': maxMembers,
      'treasury': treasury,
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
