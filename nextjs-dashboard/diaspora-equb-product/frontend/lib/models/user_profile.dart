class UserProfile {
  final String wallet;
  final String? identityHash;
  final String? faydaStatus;
  final String? displayName;

  const UserProfile({
    required this.wallet,
    this.identityHash,
    this.faydaStatus,
    this.displayName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      wallet: json['wallet']?.toString() ?? '',
      identityHash: json['identityHash']?.toString(),
      faydaStatus: json['faydaStatus']?.toString(),
      displayName: json['displayName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'wallet': wallet,
    if (identityHash != null) 'identityHash': identityHash,
    if (faydaStatus != null) 'faydaStatus': faydaStatus,
    if (displayName != null) 'displayName': displayName,
  };
}
