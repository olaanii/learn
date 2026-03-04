import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class ReferralProvider extends ChangeNotifier {
  final ApiClient _api;

  String? _referralCode;
  int _totalInvited = 0;
  int _activeReferrals = 0;
  double _totalCommission = 0;
  List<Map<String, dynamic>> _commissionHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  ReferralProvider(this._api);

  String? get referralCode => _referralCode;
  int get totalInvited => _totalInvited;
  int get activeReferrals => _activeReferrals;
  double get totalCommission => _totalCommission;
  List<Map<String, dynamic>> get commissionHistory => _commissionHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchReferralCode() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.getReferralCode();
      _referralCode = data['code']?.toString();
    } catch (e) {
      _errorMessage = 'Failed to load referral code';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchReferralStats() async {
    try {
      final data = await _api.getReferralStats();
      _totalInvited = (data['totalInvited'] as num?)?.toInt() ?? 0;
      _activeReferrals = (data['activeReferrals'] as num?)?.toInt() ?? 0;
      _totalCommission = (data['totalCommission'] as num?)?.toDouble() ?? 0;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchCommissionHistory() async {
    try {
      final data = await _api.getReferralCommissions();
      _commissionHistory = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadAll() async {
    await Future.wait([fetchReferralCode(), fetchReferralStats(), fetchCommissionHistory()]);
  }
}
