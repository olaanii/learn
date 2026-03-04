class CreditScore {
  final String wallet;
  final int score;
  final int tier;
  final int collateralRate;
  final String maxPoolSize;
  final int? nextTier;
  final int? scoreForNextTier;
  final List<CreditHistoryEntry> history;

  const CreditScore({
    required this.wallet,
    this.score = 0,
    this.tier = 0,
    this.collateralRate = 0,
    this.maxPoolSize = '0',
    this.nextTier,
    this.scoreForNextTier,
    this.history = const [],
  });

  factory CreditScore.fromJson(Map<String, dynamic> json) {
    return CreditScore(
      wallet: json['wallet']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? (json['creditScore'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as num?)?.toInt() ?? (json['eligibleTier'] as num?)?.toInt() ?? 0,
      collateralRate: (json['collateralRate'] as num?)?.toInt() ?? 0,
      maxPoolSize: json['maxPoolSize']?.toString() ?? '0',
      nextTier: (json['nextTier'] as num?)?.toInt(),
      scoreForNextTier: (json['scoreForNextTier'] as num?)?.toInt(),
      history: (json['history'] as List?)?.map((e) => CreditHistoryEntry.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'wallet': wallet, 'score': score, 'tier': tier,
    'collateralRate': collateralRate, 'maxPoolSize': maxPoolSize,
    if (nextTier != null) 'nextTier': nextTier,
    if (scoreForNextTier != null) 'scoreForNextTier': scoreForNextTier,
    'history': history.map((e) => e.toJson()).toList(),
  };
}

class CreditHistoryEntry {
  final DateTime date;
  final int score;
  final String? event;

  const CreditHistoryEntry({required this.date, required this.score, this.event});

  factory CreditHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CreditHistoryEntry(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      event: json['event']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(), 'score': score,
    if (event != null) 'event': event,
  };
}
