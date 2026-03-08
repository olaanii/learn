import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredWalletSlot {
  final String address;
  final String? label;
  final int lastUsedAt;

  const StoredWalletSlot({
    required this.address,
    this.label,
    required this.lastUsedAt,
  });

  StoredWalletSlot copyWith({
    String? address,
    String? label,
    int? lastUsedAt,
  }) {
    return StoredWalletSlot(
      address: address ?? this.address,
      label: label ?? this.label,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'label': label,
        'lastUsedAt': lastUsedAt,
      };

  factory StoredWalletSlot.fromJson(Map<String, dynamic> json) {
    return StoredWalletSlot(
      address: json['address'] as String? ?? '',
      label: json['label'] as String?,
      lastUsedAt: json['lastUsedAt'] as int? ?? 0,
    );
  }
}

class StoredProfilePreferences {
  final String? displayName;
  final String? phoneNumber;
  final String? avatarBase64;
  final bool requireTransactionConfirmation;
  final List<StoredWalletSlot> walletSlots;

  const StoredProfilePreferences({
    this.displayName,
    this.phoneNumber,
    this.avatarBase64,
    this.requireTransactionConfirmation = true,
    this.walletSlots = const [],
  });

  StoredProfilePreferences copyWith({
    String? displayName,
    String? phoneNumber,
    String? avatarBase64,
    bool? requireTransactionConfirmation,
    List<StoredWalletSlot>? walletSlots,
  }) {
    return StoredProfilePreferences(
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      requireTransactionConfirmation:
          requireTransactionConfirmation ?? this.requireTransactionConfirmation,
      walletSlots: walletSlots ?? this.walletSlots,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'avatarBase64': avatarBase64,
        'requireTransactionConfirmation': requireTransactionConfirmation,
        'walletSlots': walletSlots.map((slot) => slot.toJson()).toList(),
      };

  factory StoredProfilePreferences.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['walletSlots'] as List<dynamic>? ?? const [];
    return StoredProfilePreferences(
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      avatarBase64: json['avatarBase64'] as String?,
      requireTransactionConfirmation:
          json['requireTransactionConfirmation'] as bool? ?? true,
      walletSlots: rawSlots
          .whereType<Map>()
          .map(
            (slot) => StoredWalletSlot.fromJson(
              Map<String, dynamic>.from(slot),
            ),
          )
          .where((slot) => slot.address.trim().isNotEmpty)
          .toList(),
    );
  }
}

class ProfilePreferencesService {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'profile_preferences_v1';

  Future<StoredProfilePreferences> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return const StoredProfilePreferences();
    }
    return StoredProfilePreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<StoredProfilePreferences> save(
    StoredProfilePreferences preferences,
  ) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(preferences.toJson()),
    );
    return preferences;
  }
}
