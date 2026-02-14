import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class PoolProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Map<String, dynamic>> _pools = [];
  Map<String, dynamic>? _selectedPool;
  bool _isLoading = false;
  String? _errorMessage;

  PoolProvider(this._api);

  List<Map<String, dynamic>> get pools => _pools;
  Map<String, dynamic>? get selectedPool => _selectedPool;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<bool> joinPool(String poolId, String walletAddress) async {
    try {
      await _api.joinPool(poolId, walletAddress);
      await loadPool(poolId);
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
  }) async {
    try {
      final pool = await _api.createPool(
        tier: tier,
        contributionAmount: contributionAmount,
        maxMembers: maxMembers,
        treasury: treasury,
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
