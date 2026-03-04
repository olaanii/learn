import 'package:flutter/foundation.dart';
import '../models/proposal.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';

class GovernanceProvider extends ChangeNotifier {
  final ApiClient _api;
  final WalletService _walletService;

  List<Proposal> _activeProposals = [];
  List<Proposal> _pastProposals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastTxHash;

  GovernanceProvider(this._api, this._walletService);

  List<Proposal> get activeProposals => _activeProposals;
  List<Proposal> get pastProposals => _pastProposals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastTxHash => _lastTxHash;

  Future<void> fetchProposals(String poolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getProposals(poolId);
      final all = data
          .map((e) =>
              Proposal.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _activeProposals = all.where((p) => p.isActive).toList();
      _pastProposals = all.where((p) => !p.isActive).toList();
    } catch (e) {
      _errorMessage = 'Failed to load proposals';
      _activeProposals = [];
      _pastProposals = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> proposeRuleChange({
    required String poolId,
    required Map<String, dynamic> rules,
    required String description,
    required String callerAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildProposeTx(
        poolId: poolId,
        rules: rules,
        description: description,
        callerAddress: callerAddress,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Proposal TX rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to propose rule change: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> vote({
    required String poolId,
    required int onChainProposalId,
    required bool support,
    required String callerAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildVoteTx(
        poolId: poolId,
        onChainProposalId: onChainProposalId,
        support: support,
        callerAddress: callerAddress,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ?? 'Vote TX rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to submit vote: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> executeProposal({
    required String poolId,
    required int onChainProposalId,
    required String callerAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastTxHash = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildExecuteTx(
        poolId: poolId,
        onChainProposalId: onChainProposalId,
        callerAddress: callerAddress,
      );
      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      _lastTxHash = txHash;

      if (txHash == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Execute TX rejected';
      }

      _isLoading = false;
      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to execute proposal: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
