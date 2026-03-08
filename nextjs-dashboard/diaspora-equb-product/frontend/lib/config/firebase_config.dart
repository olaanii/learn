import 'package:firebase_core/firebase_core.dart';

class AppFirebaseConfig {
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: '',
  );
  static const String androidClientId = String.fromEnvironment(
    'FIREBASE_ANDROID_CLIENT_ID',
    defaultValue: '',
  );
  static const String iosClientId = String.fromEnvironment(
    'FIREBASE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const String measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get currentOptions {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Provide Firebase values through env-backed dart-defines before building or running the app.',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      androidClientId: androidClientId.isEmpty ? null : androidClientId,
      iosClientId: iosClientId.isEmpty ? null : iosClientId,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
