import 'equb_rules.dart';

class Equb {
  final String id;
  final String name;
  final String? type;
  final String? frequency;
  final int tier;
  final String contributionAmount;
  final int maxMembers;
  final int currentRound;
  final String creator;
  final String? token;
  final String status;
  final List<String> members;
  final EqubRules? rules;
  final double? healthScore;
  final int? onChainPoolId;
  final String? treasury;

  const Equb({
    required this.id,
    required this.name,
    this.type,
    this.frequency,
    required this.tier,
    required this.contributionAmount,
    required this.maxMembers,
    this.currentRound = 0,
    required this.creator,
    this.token,
    this.status = 'active',
    this.members = const [],
    this.rules,
    this.healthScore,
    this.onChainPoolId,
    this.treasury,
  });

  factory Equb.fromJson(Map<String, dynamic> json) {
    return Equb(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Equb',
      type: json['type']?.toString(),
      frequency: json['frequency']?.toString(),
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      contributionAmount: json['contributionAmount']?.toString() ?? '0',
      maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 0,
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
      creator: json['creator']?.toString() ?? '',
      token: json['token']?.toString(),
      status: json['status']?.toString() ?? 'active',
      members: (json['members'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rules: json['rules'] is Map<String, dynamic> ? EqubRules.fromJson(json['rules']) : null,
      healthScore: (json['healthScore'] as num?)?.toDouble(),
      onChainPoolId: (json['onChainPoolId'] as num?)?.toInt(),
      treasury: json['treasury']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (type != null) 'type': type,
    if (frequency != null) 'frequency': frequency,
    'tier': tier,
    'contributionAmount': contributionAmount,
    'maxMembers': maxMembers,
    'currentRound': currentRound,
    'creator': creator,
    if (token != null) 'token': token,
    'status': status,
    'members': members,
    if (rules != null) 'rules': rules!.toJson(),
    if (healthScore != null) 'healthScore': healthScore,
    if (onChainPoolId != null) 'onChainPoolId': onChainPoolId,
    if (treasury != null) 'treasury': treasury,
  };

  Equb copyWith({
    String? id, String? name, String? type, String? frequency,
    int? tier, String? contributionAmount, int? maxMembers,
    int? currentRound, String? creator, String? token,
    String? status, List<String>? members, EqubRules? rules,
    double? healthScore, int? onChainPoolId, String? treasury,
  }) {
    return Equb(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      tier: tier ?? this.tier,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      maxMembers: maxMembers ?? this.maxMembers,
      currentRound: currentRound ?? this.currentRound,
      creator: creator ?? this.creator,
      token: token ?? this.token,
      status: status ?? this.status,
      members: members ?? this.members,
      rules: rules ?? this.rules,
      healthScore: healthScore ?? this.healthScore,
      onChainPoolId: onChainPoolId ?? this.onChainPoolId,
      treasury: treasury ?? this.treasury,
    );
  }
}
