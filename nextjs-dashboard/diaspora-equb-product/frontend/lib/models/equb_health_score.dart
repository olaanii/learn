class EqubHealthScore {
  final String equbId;
  final double score;
  final double consistency;
  final int delayCount;
  final double avgPayoutTime;
  final double avgCredit;
  final int defaultCount;
  final double retention;
  final double dannaScore;

  const EqubHealthScore({
    required this.equbId,
    this.score = 0,
    this.consistency = 0,
    this.delayCount = 0,
    this.avgPayoutTime = 0,
    this.avgCredit = 0,
    this.defaultCount = 0,
    this.retention = 0,
    this.dannaScore = 0,
  });

  factory EqubHealthScore.fromJson(Map<String, dynamic> json) {
    return EqubHealthScore(
      equbId: json['equbId']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      consistency: (json['consistency'] as num?)?.toDouble() ?? 0,
      delayCount: (json['delayCount'] as num?)?.toInt() ?? 0,
      avgPayoutTime: (json['avgPayoutTime'] as num?)?.toDouble() ?? 0,
      avgCredit: (json['avgCredit'] as num?)?.toDouble() ?? 0,
      defaultCount: (json['defaultCount'] as num?)?.toInt() ?? 0,
      retention: (json['retention'] as num?)?.toDouble() ?? 0,
      dannaScore: (json['dannaScore'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'equbId': equbId, 'score': score, 'consistency': consistency,
    'delayCount': delayCount, 'avgPayoutTime': avgPayoutTime,
    'avgCredit': avgCredit, 'defaultCount': defaultCount,
    'retention': retention, 'dannaScore': dannaScore,
  };
}
