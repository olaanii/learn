import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'biometric_lock_enabled';

  static Future<bool> get isEnabled async {
    final value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  static Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  static Future<bool> authenticate() async {
    try {
      const channel = MethodChannel('plugins.flutter.io/local_auth');
      final result = await channel.invokeMethod<bool>('authenticate', {
        'localizedReason': 'Authenticate to access Diaspora Equb',
        'useErrorDialogs': true,
        'stickyAuth': false,
        'biometricOnly': false,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isAvailable() async {
    try {
      const channel = MethodChannel('plugins.flutter.io/local_auth');
      final result = await channel.invokeMethod<bool>('isDeviceSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
