class TokenTransaction {
  final String txHash;
  final String from;
  final String to;
  final String amount;
  final String token;
  final String type;
  final int? blockNumber;
  final DateTime? timestamp;
  final bool isError;

  const TokenTransaction({
    required this.txHash,
    required this.from,
    required this.to,
    required this.amount,
    this.token = 'USDC',
    this.type = 'transfer',
    this.blockNumber,
    this.timestamp,
    this.isError = false,
  });

  factory TokenTransaction.fromJson(Map<String, dynamic> json) {
    return TokenTransaction(
      txHash: json['txHash']?.toString() ?? json['hash']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      amount: json['amount']?.toString() ?? json['value']?.toString() ?? '0',
      token: json['token']?.toString() ?? 'USDC',
      type: json['type']?.toString() ?? 'transfer',
      blockNumber: (json['blockNumber'] as num?)?.toInt(),
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) : null,
      isError: json['isError'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'txHash': txHash, 'from': from, 'to': to,
    'amount': amount, 'token': token, 'type': type,
    if (blockNumber != null) 'blockNumber': blockNumber,
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    'isError': isError,
  };
}
