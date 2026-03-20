import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'biometric_lock_enabled';
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> get isEnabled async {
    final value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  static Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  static Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Diaspora Equb',
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return supported || canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
