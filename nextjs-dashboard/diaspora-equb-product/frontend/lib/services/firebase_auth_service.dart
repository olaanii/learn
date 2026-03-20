import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/firebase_config.dart';

class FirebaseAuthService {
  bool _isAvailable = AppFirebaseConfig.isConfigured;
  GoogleSignIn? _googleSignIn;

  bool get isConfigured => _isAvailable;
  FirebaseAuth get _auth {
    _assertConfigured();
    return FirebaseAuth.instance;
  }

  String? get _googleClientId {
    if (kIsWeb) {
      return AppFirebaseConfig.googleWebClientId.isEmpty
          ? null
          : AppFirebaseConfig.googleWebClientId;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AppFirebaseConfig.androidClientId.isEmpty
            ? null
            : AppFirebaseConfig.androidClientId;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppFirebaseConfig.iosClientId.isEmpty
            ? null
            : AppFirebaseConfig.iosClientId;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  String? get _googleServerClientId {
    if (kIsWeb || AppFirebaseConfig.googleWebClientId.isEmpty) {
      return null;
    }
    return AppFirebaseConfig.googleWebClientId;
  }

  GoogleSignIn get _googleSignInInstance {
    _assertConfigured();
    return _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: _googleClientId,
      serverClientId: _googleServerClientId,
    );
  }

  User? get currentUser =>
      isConfigured ? FirebaseAuth.instance.currentUser : null;

  Future<bool> initialize() async {
    if (!isConfigured) {
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: AppFirebaseConfig.currentOptions);
      }
      return true;
    } catch (_) {
      _isAvailable = false;
      return false;
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    _assertConfigured();
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    _assertConfigured();
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    _assertConfigured();
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    }

    final googleUser = await _googleSignInInstance.signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> sendEmailVerification() async {
    _assertConfigured();
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<User?> reloadCurrentUser() async {
    _assertConfigured();
    await _auth.currentUser?.reload();
    return _auth.currentUser;
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    _assertConfigured();
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  Future<void> updateDisplayName(String displayName) async {
    _assertConfigured();
    await _auth.currentUser?.updateDisplayName(displayName);
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      return;
    }
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  bool requiresEmailVerification(User user) {
    final usesPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    return usesPasswordProvider && !user.emailVerified;
  }

  void _assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Load Firebase values from local or deployment env and pass them as dart-defines before starting the app.',
      );
    }
  }
}
