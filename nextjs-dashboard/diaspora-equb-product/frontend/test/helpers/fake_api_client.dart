import 'dart:async';
import 'package:diaspora_equb_frontend/services/api_client.dart';

/// Shared FakeApiClient for all provider tests.
/// Override only the methods your test needs; defaults return empty/success.
class FakeApiClient extends ApiClient {
  // ── Auth ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> verifyFaydaResponse = {
    'accessToken': 'fake-jwt',
    'identityHash': '0xFakeHash',
    'walletBindingStatus': 'unbound',
  };
  bool verifyFaydaShouldThrow = false;

  Map<String, dynamic> walletChallengeResponse = {
    'message': 'Sign this message to log in to Diaspora Equb.\n\nWallet: 0xFake\nNonce: abc123\nTimestamp: 2026-01-01T00:00:00Z',
    'nonce': 'abc123',
  };

  Map<String, dynamic> walletVerifyResponse = {
    'accessToken': 'fake-jwt-wallet',
    'identityHash': '0xWalletHash',
    'walletAddress': '0xFakeWallet',
    'walletBindingStatus': 'bound',
  };

  Map<String, dynamic> devLoginResponse = {
    'accessToken': 'fake-jwt-dev',
    'identityHash': '0xDevHash',
    'walletAddress': '0x0000000000000000000000000000000000DE1057',
    'walletBindingStatus': 'bound',
  };

  String? savedToken;

  @override
  Future<Map<String, dynamic>> verifyFayda(String token) async {
    if (verifyFaydaShouldThrow) throw Exception('Fayda verification failed');
    return verifyFaydaResponse;
  }

  @override
  Future<Map<String, dynamic>> walletChallenge(String walletAddress) async {
    return walletChallengeResponse;
  }

  @override
  Future<Map<String, dynamic>> walletVerify({
    required String walletAddress,
    required String signature,
    required String message,
  }) async {
    return walletVerifyResponse;
  }

  @override
  Future<Map<String, dynamic>> devLogin({String? walletAddress}) async {
    return devLoginResponse;
  }

  @override
  Future<void> saveToken(String token) async {
    savedToken = token;
  }

  @override
  Future<void> clearToken() async {
    savedToken = null;
  }

  @override
  Future<String?> getToken() async => savedToken;

  // ── Pools ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> poolsList = [];
  Map<String, dynamic> poolDetail = {};
  Map<String, dynamic> buildCreatePoolResponse = {
    'to': '0xPool',
    'data': '0x1',
    'value': '0',
    'chainId': 102031,
    'estimatedGas': '200000',
  };
  Map<String, dynamic> buildJoinPoolResponse = {
    'to': '0xPool',
    'data': '0x2',
    'value': '0',
    'chainId': 102031,
  };
  Map<String, dynamic> buildContributeResponse = {
    'to': '0xPool',
    'data': '0x3',
    'value': '1000',
    'chainId': 102031,
  };
  Map<String, dynamic> fromCreationTxResponse = {'id': 'pool-1', 'status': 'active'};
  Map<String, dynamic> closeActiveRoundResponse = {'status': 'closed'};
  Map<String, dynamic> pickWinnerResponse = {'winner': {'wallet': '0xWinner'}};
  bool poolApiShouldThrow = false;

  @override
  Future<List<dynamic>> listPools({int? tier}) async {
    if (poolApiShouldThrow) throw Exception('API error');
    return poolsList;
  }

  @override
  Future<Map<String, dynamic>> getPool(String id) async {
    if (poolApiShouldThrow) throw Exception('API error');
    return poolDetail;
  }

  @override
  Future<Map<String, dynamic>> buildCreatePool({
    required int tier,
    required String contributionAmount,
    required int maxMembers,
    required String treasury,
    String? token,
  }) async {
    return buildCreatePoolResponse;
  }

  @override
  Future<Map<String, dynamic>> createPoolFromCreationTx(String txHash) async {
    return fromCreationTxResponse;
  }

  @override
  Future<Map<String, dynamic>> buildJoinPool(
    int onChainPoolId, {
    String? caller,
  }) async {
    return buildJoinPoolResponse;
  }

  @override
  Future<Map<String, dynamic>> buildContribute({
    required int onChainPoolId,
    required String contributionAmount,
    String? tokenAddress,
  }) async {
    return buildContributeResponse;
  }

  @override
  Future<Map<String, dynamic>> getEligibleWinners(String poolId) async {
    return {'eligible': ['0xMember1', '0xMember2'], 'roundNumber': 1};
  }

  @override
  Future<Map<String, dynamic>> closeActiveRound(String poolId) async {
    return closeActiveRoundResponse;
  }

  @override
  Future<Map<String, dynamic>> pickWinnerForActiveRound({
    required String poolId,
    required String idempotencyKey,
    String mode = 'auto',
  }) async {
    return pickWinnerResponse;
  }

  // ── Token / Wallet ────────────────────────────────────────────────────────
  Map<String, dynamic> balanceResponse = {
    'formatted': '100.00',
    'balance': '100000000',
    'decimals': 6,
    'symbol': 'USDC',
  };
  List<Map<String, dynamic>> transactionsResponse = [];
  Map<String, dynamic> ratesResponse = {
    'rates': {'CTC': 0.5, 'USDC': 1.0, 'USDT': 1.0},
  };
  Map<String, dynamic> faucetResponse = {'txHash': '0xFaucetTx'};
  Map<String, dynamic> buildTransferResponse = {
    'to': '0xToken',
    'data': '0x',
    'value': '0',
    'chainId': 102031,
  };
  bool walletApiShouldThrow = false;

  @override
  Future<Map<String, dynamic>> getTokenBalance(String walletAddress,
      {String token = 'USDC', String? tokenAddress}) async {
    if (walletApiShouldThrow) throw Exception('API error');
    return balanceResponse;
  }

  @override
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
    return transactionsResponse;
  }

  @override
  Future<Map<String, dynamic>> getExchangeRates() async {
    return ratesResponse;
  }

  @override
  Future<Map<String, dynamic>> requestFaucet({
    required String walletAddress,
    double amount = 1000,
    String token = 'USDC',
  }) async {
    return faucetResponse;
  }

  @override
  Future<Map<String, dynamic>> buildTransfer({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
  }) async {
    return buildTransferResponse;
  }

  @override
  Future<Map<String, dynamic>> buildWithdraw({
    required String from,
    required String to,
    required String amount,
    String token = 'USDC',
    String network = 'ERC-20',
  }) async {
    return buildTransferResponse;
  }
}
