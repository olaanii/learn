class Proposal {
  final String id;
  final String poolId;
  final int? onChainProposalId;
  final String? ruleHash;
  final String description;
  final int yesVotes;
  final int noVotes;
  final DateTime? deadline;
  final String status;
  final Map<String, dynamic>? proposedRules;
  final String? proposer;

  const Proposal({
    required this.id,
    required this.poolId,
    this.onChainProposalId,
    this.ruleHash,
    required this.description,
    this.yesVotes = 0,
    this.noVotes = 0,
    this.deadline,
    this.status = 'active',
    this.proposedRules,
    this.proposer,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['id']?.toString() ?? '',
      poolId: json['poolId']?.toString() ?? '',
      onChainProposalId: (json['onChainProposalId'] as num?)?.toInt(),
      ruleHash: json['ruleHash']?.toString(),
      description: json['description']?.toString() ?? '',
      yesVotes: (json['yesVotes'] as num?)?.toInt() ?? 0,
      noVotes: (json['noVotes'] as num?)?.toInt() ?? 0,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      status: json['status']?.toString() ?? 'active',
      proposedRules: json['proposedRules'] is Map
          ? Map<String, dynamic>.from(json['proposedRules'] as Map)
          : null,
      proposer: json['proposer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'poolId': poolId,
        if (onChainProposalId != null)
          'onChainProposalId': onChainProposalId,
        if (ruleHash != null) 'ruleHash': ruleHash,
        'description': description,
        'yesVotes': yesVotes,
        'noVotes': noVotes,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        'status': status,
        if (proposedRules != null) 'proposedRules': proposedRules,
        if (proposer != null) 'proposer': proposer,
      };

  int get totalVotes => yesVotes + noVotes;
  double get yesPercent => totalVotes > 0 ? yesVotes / totalVotes : 0;
  bool get isPassed => status == 'passed' || status == 'executed';
  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired =>
      deadline != null && DateTime.now().isAfter(deadline!) && isActive;

  String get timeRemaining {
    if (deadline == null) return 'No deadline';
    final diff = deadline!.difference(DateTime.now());
    if (diff.isNegative) return 'Voting ended';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h left';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    return '${diff.inMinutes}m left';
  }
}
