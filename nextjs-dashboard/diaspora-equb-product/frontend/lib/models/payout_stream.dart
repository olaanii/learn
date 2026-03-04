class PayoutStream {
  final String? poolId;
  final String beneficiary;
  final String total;
  final String released;
  final bool frozen;
  final int upfrontPercent;
  final int totalRounds;

  const PayoutStream({
    this.poolId,
    required this.beneficiary,
    required this.total,
    this.released = '0',
    this.frozen = false,
    this.upfrontPercent = 0,
    this.totalRounds = 0,
  });

  factory PayoutStream.fromJson(Map<String, dynamic> json) {
    return PayoutStream(
      poolId: json['poolId']?.toString(),
      beneficiary: json['beneficiary']?.toString() ?? '',
      total: json['total']?.toString() ?? '0',
      released: json['released']?.toString() ?? '0',
      frozen: json['frozen'] == true,
      upfrontPercent: (json['upfrontPercent'] as num?)?.toInt() ?? 0,
      totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (poolId != null) 'poolId': poolId,
    'beneficiary': beneficiary, 'total': total, 'released': released,
    'frozen': frozen, 'upfrontPercent': upfrontPercent, 'totalRounds': totalRounds,
  };
}
