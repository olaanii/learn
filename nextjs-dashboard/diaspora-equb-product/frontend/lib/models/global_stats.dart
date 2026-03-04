class GlobalStats {
  final double tvl;
  final int activeEqubs;
  final int totalMembers;
  final double completionRate;
  final double defaultRate;
  final double avgPayoutTime;

  const GlobalStats({
    this.tvl = 0,
    this.activeEqubs = 0,
    this.totalMembers = 0,
    this.completionRate = 0,
    this.defaultRate = 0,
    this.avgPayoutTime = 0,
  });

  factory GlobalStats.fromJson(Map<String, dynamic> json) {
    return GlobalStats(
      tvl: (json['tvl'] as num?)?.toDouble() ?? 0,
      activeEqubs: (json['activeEqubs'] as num?)?.toInt() ?? 0,
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      defaultRate: (json['defaultRate'] as num?)?.toDouble() ?? 0,
      avgPayoutTime: (json['avgPayoutTime'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'tvl': tvl, 'activeEqubs': activeEqubs, 'totalMembers': totalMembers,
    'completionRate': completionRate, 'defaultRate': defaultRate,
    'avgPayoutTime': avgPayoutTime,
  };
}
