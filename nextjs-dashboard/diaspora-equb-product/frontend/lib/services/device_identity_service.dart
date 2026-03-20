import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentityService {
  static const _storage = FlutterSecureStorage();
  static const _fingerprintKey = 'trusted_device_fingerprint_v1';

  Future<String> getOrCreateFingerprint() async {
    final existing = await _storage.read(key: _fingerprintKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    final fingerprint =
        values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _fingerprintKey, value: fingerprint);
    return fingerprint;
  }

  Future<String> currentLabel() async {
    if (kIsWeb) {
      return 'Web browser';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android device';
      case TargetPlatform.iOS:
        return 'iPhone or iPad';
      case TargetPlatform.macOS:
        return 'macOS desktop';
      case TargetPlatform.windows:
        return 'Windows desktop';
      case TargetPlatform.linux:
        return 'Linux desktop';
      case TargetPlatform.fuchsia:
        return 'Fuchsia device';
    }
  }
}
