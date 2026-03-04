class DannaReputation {
  final String address;
  final int totalCreated;
  final double avgCompletion;
  final double avgCredit;
  final int totalMembers;
  final int longestStreak;
  final int activeCount;

  const DannaReputation({
    required this.address,
    this.totalCreated = 0,
    this.avgCompletion = 0,
    this.avgCredit = 0,
    this.totalMembers = 0,
    this.longestStreak = 0,
    this.activeCount = 0,
  });

  factory DannaReputation.fromJson(Map<String, dynamic> json) {
    return DannaReputation(
      address: json['address']?.toString() ?? '',
      totalCreated: (json['totalCreated'] as num?)?.toInt() ?? 0,
      avgCompletion: (json['avgCompletion'] as num?)?.toDouble() ?? 0,
      avgCredit: (json['avgCredit'] as num?)?.toDouble() ?? 0,
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'address': address, 'totalCreated': totalCreated,
    'avgCompletion': avgCompletion, 'avgCredit': avgCredit,
    'totalMembers': totalMembers, 'longestStreak': longestStreak,
    'activeCount': activeCount,
  };
}
