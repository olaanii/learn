class Collateral {
  final String? wallet;
  final String? poolId;
  final String lockedAmount;
  final String availableBalance;
  final String slashedAmount;
  final String? source;

  const Collateral({
    this.wallet,
    this.poolId,
    this.lockedAmount = '0',
    this.availableBalance = '0',
    this.slashedAmount = '0',
    this.source,
  });

  factory Collateral.fromJson(Map<String, dynamic> json) {
    return Collateral(
      wallet: json['wallet']?.toString(),
      poolId: json['poolId']?.toString(),
      lockedAmount: json['lockedAmount']?.toString() ?? '0',
      availableBalance: json['availableBalance']?.toString() ?? '0',
      slashedAmount: json['slashedAmount']?.toString() ?? '0',
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (wallet != null) 'wallet': wallet,
    if (poolId != null) 'poolId': poolId,
    'lockedAmount': lockedAmount, 'availableBalance': availableBalance,
    'slashedAmount': slashedAmount,
    if (source != null) 'source': source,
  };
}
