import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class EqubInsightsProvider extends ChangeNotifier {
  final ApiClient _api;
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'equb_insights_filters:';

  Timer? _debounce;
  String? _activeWalletLower;

  EqubInsightsProvider(this._api);

  String _timeRange = '7d';
  String _token = 'all';
  String _status = 'all';
  String _metric = 'joins';
  String _bucket = 'day';

  bool _popularLoading = false;
  bool _joinedLoading = false;
  bool _summaryLoading = false;

  String? _popularError;
  String? _joinedError;
  String? _summaryError;

  List<Map<String, dynamic>> _popularSeries = [];
  List<Map<String, dynamic>> _joinedPools = [];
  Map<String, dynamic> _summary = const {
    'activePools': 0,
    'endingSoon': 0,
    'winnerPending': 0,
  };

  String get timeRange => _timeRange;
  String get token => _token;
  String get status => _status;
  String get metric => _metric;
  String get bucket => _bucket;

  bool get popularLoading => _popularLoading;
  bool get joinedLoading => _joinedLoading;
  bool get summaryLoading => _summaryLoading;

  String? get popularError => _popularError;
  String? get joinedError => _joinedError;
  String? get summaryError => _summaryError;

  List<Map<String, dynamic>> get popularSeries => _popularSeries;
  List<Map<String, dynamic>> get joinedPools => _joinedPools;
  Map<String, dynamic> get summary => _summary;

  bool get popularEmpty => !_popularLoading && _popularError == null && _popularSeries.isEmpty;
  bool get joinedEmpty => !_joinedLoading && _joinedError == null && _joinedPools.isEmpty;

  Future<void> initializeForWallet(String wallet) async {
    final walletLower = wallet.toLowerCase();
    if (_activeWalletLower == walletLower) {
      return;
    }

    _activeWalletLower = walletLower;
    await _restoreFilters();
    await loadAll(wallet);
  }

  void clearWalletContext() {
    _activeWalletLower = null;
    _debounce?.cancel();
  }

  void setTimeRange(String value) {
    _timeRange = value;
    _bucket = value == '24h' ? 'hour' : 'day';
    notifyListeners();
    _persistAndDebounceReload();
  }

  void setToken(String value) {
    _token = value;
    notifyListeners();
    _persistAndDebounceReload();
  }

  void setStatus(String value) {
    _status = value;
    notifyListeners();
    _persistAndDebounceReload();
  }

  void setMetric(String value) {
    _metric = value;
    notifyListeners();
    _persistAndDebounceReload();
  }

  Future<void> applyFiltersAndReload(String wallet) async {
    await _persistFilters();
    await loadAll(wallet);
  }

  Future<void> refresh(String wallet) async {
    await loadAll(wallet);
  }

  Future<void> loadAll(String wallet) async {
    await Future.wait([
      loadPopular(),
      loadJoined(wallet),
      loadSummary(wallet),
    ]);
  }

  Future<void> loadPopular() async {
    _popularLoading = true;
    _popularError = null;
    notifyListeners();

    try {
      final window = _resolveWindow();
      final response = await _api.getEqubPopularSeries(
        from: window.$1,
        to: window.$2,
        token: _token,
        status: _status,
        metric: _metric,
        limit: 5,
        bucket: _bucket,
      );

      final raw = (response['series'] as List?) ?? [];
      _popularSeries = raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      _popularError = 'Failed to load popular trends';
      _popularSeries = [];
    }

    _popularLoading = false;
    notifyListeners();
  }

  Future<void> loadJoined(String wallet) async {
    _joinedLoading = true;
    _joinedError = null;
    notifyListeners();

    try {
      final window = _resolveWindow();
      final response = await _api.getEqubJoinedProgress(
        wallet: wallet,
        from: window.$1,
        to: window.$2,
        token: _token,
        status: _status,
        bucket: _bucket,
      );

      final raw = (response['pools'] as List?) ?? [];
      _joinedPools = raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      _joinedError = 'Failed to load joined progress';
      _joinedPools = [];
    }

    _joinedLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary(String wallet) async {
    _summaryLoading = true;
    _summaryError = null;
    notifyListeners();

    try {
      final window = _resolveWindow();
      final response = await _api.getEqubSummary(
        wallet: wallet,
        from: window.$1,
        to: window.$2,
        token: _token,
        status: _status,
      );

      _summary = {
        'activePools': response['activePools'] ?? 0,
        'endingSoon': response['endingSoon'] ?? 0,
        'winnerPending': response['winnerPending'] ?? 0,
      };
    } catch (e) {
      _summaryError = 'Failed to load summary';
      _summary = const {
        'activePools': 0,
        'endingSoon': 0,
        'winnerPending': 0,
      };
    }

    _summaryLoading = false;
    notifyListeners();
  }

  Future<void> retryPopular() => loadPopular();
  Future<void> retryJoined(String wallet) => loadJoined(wallet);
  Future<void> retrySummary(String wallet) => loadSummary(wallet);

  Future<void> _persistFilters() async {
    final key = _storageKey;
    if (key == null) return;

    final payload = jsonEncode({
      'timeRange': _timeRange,
      'token': _token,
      'status': _status,
      'metric': _metric,
      'bucket': _bucket,
    });

    await _storage.write(key: key, value: payload);
  }

  Future<void> _restoreFilters() async {
    final key = _storageKey;
    if (key == null) {
      _setDefaults();
      return;
    }

    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) {
      _setDefaults();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _setDefaults();
        return;
      }

      _timeRange = _validTimeRange(decoded['timeRange'] as String?)
          ? decoded['timeRange'] as String
          : '7d';
      _token = _validToken(decoded['token'] as String?)
          ? decoded['token'] as String
          : 'all';
      _status = _validStatus(decoded['status'] as String?)
          ? decoded['status'] as String
          : 'all';
      _metric = _validMetric(decoded['metric'] as String?)
          ? decoded['metric'] as String
          : 'joins';
      _bucket = _validBucket(decoded['bucket'] as String?)
          ? decoded['bucket'] as String
          : (_timeRange == '24h' ? 'hour' : 'day');
      notifyListeners();
    } catch (_) {
      _setDefaults();
    }
  }

  void _setDefaults() {
    _timeRange = '7d';
    _token = 'all';
    _status = 'all';
    _metric = 'joins';
    _bucket = 'day';
    notifyListeners();
  }

  String? get _storageKey {
    if (_activeWalletLower == null || _activeWalletLower!.isEmpty) {
      return null;
    }
    return '$_keyPrefix$_activeWalletLower';
  }

  bool _validTimeRange(String? value) =>
      value != null && const {'24h', '7d', '30d', '90d'}.contains(value);

  bool _validToken(String? value) =>
      value != null && const {'all', 'usdc', 'usdt', 'native'}.contains(value.toLowerCase());

  bool _validStatus(String? value) =>
      value != null && const {'all', 'active', 'completed', 'pending-onchain', 'cancelled'}.contains(value.toLowerCase());

  bool _validMetric(String? value) =>
      value != null && const {'joins', 'contributions'}.contains(value.toLowerCase());

  bool _validBucket(String? value) =>
      value != null && const {'hour', 'day'}.contains(value);

  void _persistAndDebounceReload() {
    unawaited(_persistFilters());
    final wallet = _activeWalletLower;
    if (wallet == null || wallet.isEmpty) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(loadAll(wallet));
    });
  }

  (int from, int to) _resolveWindow() {
    final now = DateTime.now();
    late final Duration lookback;

    switch (_timeRange) {
      case '24h':
        lookback = const Duration(hours: 24);
        break;
      case '30d':
        lookback = const Duration(days: 30);
        break;
      case '90d':
        lookback = const Duration(days: 90);
        break;
      case '7d':
      default:
        lookback = const Duration(days: 7);
        break;
    }

    final from = now.subtract(lookback).millisecondsSinceEpoch;
    final to = now.millisecondsSinceEpoch;
    return (from, to);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
