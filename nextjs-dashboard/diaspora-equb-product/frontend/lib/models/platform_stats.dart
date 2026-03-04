class PlatformStats {
  final List<TimeSeriesPoint> tvlHistory;
  final List<TimeSeriesPoint> memberHistory;
  final List<TimeSeriesPoint> completionHistory;
  final String timeRange;

  const PlatformStats({
    this.tvlHistory = const [],
    this.memberHistory = const [],
    this.completionHistory = const [],
    this.timeRange = '30d',
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      tvlHistory: _parseTimeSeries(json['tvlHistory']),
      memberHistory: _parseTimeSeries(json['memberHistory']),
      completionHistory: _parseTimeSeries(json['completionHistory']),
      timeRange: json['timeRange']?.toString() ?? '30d',
    );
  }

  static List<TimeSeriesPoint> _parseTimeSeries(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => TimeSeriesPoint.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Map<String, dynamic> toJson() => {
    'tvlHistory': tvlHistory.map((e) => e.toJson()).toList(),
    'memberHistory': memberHistory.map((e) => e.toJson()).toList(),
    'completionHistory': completionHistory.map((e) => e.toJson()).toList(),
    'timeRange': timeRange,
  };
}

class TimeSeriesPoint {
  final DateTime date;
  final double value;

  const TimeSeriesPoint({required this.date, required this.value});

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'value': value};
}
