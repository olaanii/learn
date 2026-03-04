class Contribution {
  final String? poolId;
  final String wallet;
  final int round;
  final String? txHash;
  final String status;
  final DateTime? timestamp;

  const Contribution({
    this.poolId,
    required this.wallet,
    required this.round,
    this.txHash,
    this.status = 'confirmed',
    this.timestamp,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      poolId: json['poolId']?.toString(),
      wallet: json['wallet']?.toString() ?? '',
      round: (json['round'] as num?)?.toInt() ?? 0,
      txHash: json['txHash']?.toString(),
      status: json['status']?.toString() ?? 'confirmed',
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (poolId != null) 'poolId': poolId,
    'wallet': wallet, 'round': round,
    if (txHash != null) 'txHash': txHash,
    'status': status,
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
  };
}
