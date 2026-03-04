class EqubRules {
  final String? type;
  final String? frequency;
  final String? contributionAmount;
  final int? maxMembers;
  final String? payoutMethod;
  final int? gracePeriodSeconds;
  final int? penaltySeverity;
  final double? collateralRatio;
  final int? roundDurationSeconds;
  final double? lateFeePercent;

  const EqubRules({
    this.type,
    this.frequency,
    this.contributionAmount,
    this.maxMembers,
    this.payoutMethod,
    this.gracePeriodSeconds,
    this.penaltySeverity,
    this.collateralRatio,
    this.roundDurationSeconds,
    this.lateFeePercent,
  });

  factory EqubRules.fromJson(Map<String, dynamic> json) {
    return EqubRules(
      type: json['type']?.toString(),
      frequency: json['frequency']?.toString(),
      contributionAmount: json['contributionAmount']?.toString(),
      maxMembers: (json['maxMembers'] as num?)?.toInt(),
      payoutMethod: json['payoutMethod']?.toString(),
      gracePeriodSeconds: (json['gracePeriodSeconds'] as num?)?.toInt(),
      penaltySeverity: (json['penaltySeverity'] as num?)?.toInt(),
      collateralRatio: (json['collateralRatio'] as num?)?.toDouble(),
      roundDurationSeconds: (json['roundDurationSeconds'] as num?)?.toInt(),
      lateFeePercent: (json['lateFeePercent'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (frequency != null) 'frequency': frequency,
    if (contributionAmount != null) 'contributionAmount': contributionAmount,
    if (maxMembers != null) 'maxMembers': maxMembers,
    if (payoutMethod != null) 'payoutMethod': payoutMethod,
    if (gracePeriodSeconds != null) 'gracePeriodSeconds': gracePeriodSeconds,
    if (penaltySeverity != null) 'penaltySeverity': penaltySeverity,
    if (collateralRatio != null) 'collateralRatio': collateralRatio,
    if (roundDurationSeconds != null) 'roundDurationSeconds': roundDurationSeconds,
    if (lateFeePercent != null) 'lateFeePercent': lateFeePercent,
  };

  EqubRules copyWith({
    String? type, String? frequency, String? contributionAmount,
    int? maxMembers, String? payoutMethod, int? gracePeriodSeconds,
    int? penaltySeverity, double? collateralRatio,
    int? roundDurationSeconds, double? lateFeePercent,
  }) {
    return EqubRules(
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      maxMembers: maxMembers ?? this.maxMembers,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
      penaltySeverity: penaltySeverity ?? this.penaltySeverity,
      collateralRatio: collateralRatio ?? this.collateralRatio,
      roundDurationSeconds: roundDurationSeconds ?? this.roundDurationSeconds,
      lateFeePercent: lateFeePercent ?? this.lateFeePercent,
    );
  }
}
