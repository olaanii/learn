import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../services/firebase_auth_service.dart';
import '../services/profile_preferences_service.dart';
import '../services/wallet_service.dart';

enum AuthStatus {
  unauthenticated,
  loading,
  emailVerificationRequired,
  authenticated,
  walletBound
}

class AuthProvider extends ChangeNotifier {
  static const _onboardingKey = 'onboarding_complete';
  static const _storage = FlutterSecureStorage();

  final ApiClient _api;
  final WalletService _walletService;
  final FirebaseAuthService _firebaseAuthService;
  final ProfilePreferencesService _profilePreferencesService;

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _identityHash;
  String? _walletAddress;
  String? _errorMessage;
  String? _firebaseUid;
  String? _email;
  String? _displayName;
  String? _photoUrl;
  String? _profileDisplayName;
  String? _profilePhoneNumber;
  String? _avatarBase64;
  bool _hasCompletedOnboarding = false;
  bool _requireTransactionConfirmation = true;
  List<StoredWalletSlot> _rememberedWallets = const [];

  AuthProvider(
    this._api,
    this._walletService,
    this._firebaseAuthService,
    this._profilePreferencesService,
  );

  AuthStatus get status => _status;
  String? get identityHash => _identityHash;
  String? get walletAddress => _walletAddress;
  String? get errorMessage => _errorMessage;
  String? get firebaseUid => _firebaseUid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get photoUrl => _photoUrl;
  String? get localDisplayName => _profileDisplayName;
  String? get phoneNumber => _profilePhoneNumber;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isEmailVerificationPending =>
      _status == AuthStatus.emailVerificationRequired;
  bool get isFirebaseConfigured => _firebaseAuthService.isConfigured;
  bool get requireTransactionConfirmation => _requireTransactionConfirmation;
    List<StoredWalletSlot> get rememberedWallets =>
      List.unmodifiable(_rememberedWallets);
  bool get hasBoundWallet =>
      _walletAddress != null && _walletAddress!.trim().isNotEmpty;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.walletBound;
  Uint8List? get avatarBytes => _avatarBase64 == null || _avatarBase64!.isEmpty
      ? null
      : base64Decode(_avatarBase64!);
  String get effectiveDisplayName {
    final localName = _profileDisplayName?.trim();
    if (localName != null && localName.isNotEmpty) {
      return localName;
    }
    final remoteName = _displayName?.trim();
    if (remoteName != null && remoteName.isNotEmpty) {
      return remoteName;
    }
    final userEmail = _email?.trim();
    if (userEmail != null && userEmail.isNotEmpty && userEmail.contains('@')) {
      return userEmail.split('@').first;
    }
    if (_walletAddress != null && _walletAddress!.length >= 10) {
      return '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}';
    }
    return 'Diaspora Member';
  }

  /// Access the wallet service for signing transactions.
  WalletService get walletService => _walletService;

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _storage.write(key: _onboardingKey, value: 'true');
    notifyListeners();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('No Firebase user returned.');
      }
      _setFirebaseUser(user);
      if (_firebaseAuthService.requiresEmailVerification(user)) {
        _status = AuthStatus.emailVerificationRequired;
      } else {
        await _completeFirebaseSession(user);
      }
    } catch (e) {
      _errorMessage = 'Email sign-in failed: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuthService.signUpWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('No Firebase user returned.');
      }
      _setFirebaseUser(user);
      await _firebaseAuthService.sendEmailVerification();
      _status = AuthStatus.emailVerificationRequired;
    } catch (e) {
      _errorMessage = 'Account creation failed: $e';
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuthService.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        throw StateError('No Firebase user returned.');
      }
      _setFirebaseUser(user);
      await _completeFirebaseSession(user);
    } catch (e) {
      _errorMessage = 'Google sign-in failed: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> sendEmailVerification() async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseAuthService.sendEmailVerification();
    } catch (e) {
      _errorMessage = 'Failed to send verification email: $e';
      notifyListeners();
    }
  }

  Future<void> refreshEmailVerificationStatus() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _firebaseAuthService.reloadCurrentUser();
      if (user == null) {
        throw StateError('Your Firebase session is no longer available.');
      }
      _setFirebaseUser(user);
      if (_firebaseAuthService.requiresEmailVerification(user)) {
        _status = AuthStatus.emailVerificationRequired;
      } else {
        await _completeFirebaseSession(user);
      }
    } catch (e) {
      _errorMessage = 'Email verification refresh failed: $e';
      _status = AuthStatus.emailVerificationRequired;
      notifyListeners();
    }
  }

  Future<void> updateProfilePreferences({
    required String displayName,
    required String phoneNumber,
    String? avatarBase64,
  }) async {
    _errorMessage = null;

    try {
      if (displayName.trim().isNotEmpty &&
          _firebaseAuthService.currentUser != null) {
        await _firebaseAuthService.updateDisplayName(displayName.trim());
        _displayName = _firebaseAuthService.currentUser?.displayName;
      }

      final saved = await _profilePreferencesService.save(
        _currentStoredProfile().copyWith(
          displayName: displayName.trim().isEmpty ? null : displayName.trim(),
          phoneNumber: phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
          avatarBase64: avatarBase64 ?? _avatarBase64,
        ),
      );
      _applyStoredProfile(saved);
    } catch (e) {
      _errorMessage = 'Profile update failed: $e';
    }

    notifyListeners();
  }

  Future<void> updateTransactionConfirmationPreference(bool value) async {
    _requireTransactionConfirmation = value;
    final saved = await _profilePreferencesService.save(
      _currentStoredProfile().copyWith(
        requireTransactionConfirmation: value,
      ),
    );
    _applyStoredProfile(saved);
    notifyListeners();
  }

  Future<void> saveRememberedWallet(
    String walletAddress, {
    String? label,
  }) async {
    await _rememberWallet(walletAddress, preferredLabel: label);
    notifyListeners();
  }

  Future<void> renameRememberedWallet(String walletAddress, String label) async {
    final normalized = walletAddress.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    _rememberedWallets = _rememberedWallets.map((slot) {
      if (slot.address.toLowerCase() != normalized) {
        return slot;
      }
      return slot.copyWith(label: label.trim().isEmpty ? null : label.trim());
    }).toList(growable: false);
    await _persistStoredProfile();
    notifyListeners();
  }

  Future<void> removeRememberedWallet(String walletAddress) async {
    final normalized = walletAddress.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    _rememberedWallets = _rememberedWallets
        .where((slot) => slot.address.toLowerCase() != normalized)
        .toList(growable: false);
    await _persistStoredProfile();
    notifyListeners();
  }

  Future<void> verifyFayda(String token) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.verifyFayda(token);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];

      if (response['walletBindingStatus'] == 'bound') {
        _walletAddress = response['walletAddress'];
        _status = AuthStatus.walletBound;
      } else {
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      _errorMessage = 'Fayda verification failed. Please try again.';
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Bypass Fayda verification for testing.
  /// Dev login always uses the fixed dev wallet (DE1057) that joined the tier-0 pool,
  /// so pool membership and authorized API calls work. Does not use MetaMask for auth.
  Future<void> skipFaydaForTesting() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Always use DE1057 for dev so this identity is the one that joined the pool
      const devWallet = '0x0000000000000000000000000000000000DE1057';
      final response = await _api.devLogin(walletAddress: devWallet);
      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = devWallet;
      _status = AuthStatus.walletBound;
    } catch (e) {
      _identityHash =
          '0x0000000000000000000000000000000000000000000000000000000000de1057';
      _walletAddress = '0x0000000000000000000000000000000000DE1057';
      _status = AuthStatus.walletBound;
      _errorMessage = 'Dev login failed — API calls may not work: $e';
    }

    notifyListeners();
  }

  /// Whether the dev bypass button should be shown on the onboarding screen.
  bool get isDevBypassEnabled => AppConfig.devBypassFayda;

  /// Wallet-only login using Sign-In with Ethereum:
  /// Step 1: Connect MetaMask → get wallet address
  Future<void> connectWallet() async {
    final previousStatus = _status;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final address = await _walletService.connect();
      if (address == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Wallet connection failed';
        _status = previousStatus;
        notifyListeners();
        return;
      }

      debugPrint('Wallet connected with address: $address');
      _walletAddress = address;
      await _rememberWallet(address);
      _status = previousStatus;
    } catch (e) {
      _errorMessage = 'Wallet connection failed: $e';
      _status = previousStatus;
    }

    notifyListeners();
  }

  /// Step 2: Sign the challenge with MetaMask
  Future<void> signWalletChallenge() async {
    if (_walletAddress == null) {
      _errorMessage = 'No wallet address available';
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Request challenge
      final challenge = await _api.walletChallenge(_walletAddress!);
      final message = challenge['message'] as String;

      // Sign the challenge with MetaMask

      final signature = await _walletService.personalSign(message);
      if (signature == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Message signing rejected';
        _status = AuthStatus.authenticated;
        notifyListeners();
        return;
      }

      // Verify signature and get JWT
      final response = await _api.walletVerify(
        walletAddress: _walletAddress!,
        signature: signature,
        message: message,
      );

      await _api.saveToken(response['accessToken']);
      _identityHash = response['identityHash'];
      _walletAddress = _walletAddress;
      _status = AuthStatus.walletBound;
    } catch (e) {
      _errorMessage = 'Wallet signing failed: $e';
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  /// Legacy method - connects and signs in one go
  Future<void> loginWithWalletOnly() async {
    await connectWallet();
  }

  /// Bind wallet using WalletConnect: connect the user's real wallet,
  /// then bind the wallet address to their identity on the backend.
  Future<void> connectAndBindWallet() async {
    if (_identityHash == null) {
      _errorMessage = 'Sign in before binding a wallet.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Connect via WalletConnect (user approves in their wallet app)
      final address = await _walletService.connect();
      if (address == null) {
        _errorMessage =
            _walletService.errorMessage ?? 'Wallet connection failed';
        notifyListeners();
        return;
      }

      // 2. Bind the wallet address from WalletConnect to the identity
      final response = await _api.bindWallet(_identityHash!, address);
      if (response['status'] == 'bound') {
        await _applyAuthenticatedSession(response);
        await _rememberWallet(address);
      } else {
        _errorMessage = 'Wallet binding failed: ${response['status']}';
      }
    } catch (e) {
      _errorMessage = 'Failed to connect wallet: $e';
    }

    notifyListeners();
  }

  /// Legacy: bind wallet by pasting an address (kept for dev/test).
  Future<void> bindWallet(String walletAddress) async {
    if (_identityHash == null) {
      _errorMessage = 'Sign in before binding a wallet.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.bindWallet(_identityHash!, walletAddress);
      if (response['status'] == 'bound') {
        await _applyAuthenticatedSession(response);
        await _rememberWallet(walletAddress);
      } else {
        _errorMessage = 'Wallet binding failed: ${response['status']}';
      }
    } catch (e) {
      _errorMessage = 'Failed to bind wallet. Please try again.';
    }

    notifyListeners();
  }

  /// Build and sign on-chain identity binding TX via IdentityRegistry.
  /// Required before joinPool succeeds on-chain.
  Future<String?> bindIdentityOnChain() async {
    if (_identityHash == null || _walletAddress == null) {
      _errorMessage =
          'Missing identity or wallet. Complete login and wallet binding first.';
      notifyListeners();
      return null;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final unsignedTx = await _api.buildStoreOnChain(
        identityHash: _identityHash!,
        walletAddress: _walletAddress!,
      );

      final txHash = await _walletService.signAndSendTransaction(unsignedTx);
      if (txHash == null) {
        _errorMessage = _walletService.errorMessage ??
            'Identity binding transaction rejected';
        notifyListeners();
        return null;
      }

      notifyListeners();
      return txHash;
    } catch (e) {
      _errorMessage = 'Failed to bind identity on-chain: $e';
      notifyListeners();
      return null;
    }
  }

  /// Valid EVM address regex (0x + 40 hex chars).
  static final _evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');

  Future<void> tryAutoLogin() async {
    final storedProfile = await _profilePreferencesService.load();
    _applyStoredProfile(storedProfile);

    final onboardingValue = await _storage.read(key: _onboardingKey);
    _hasCompletedOnboarding = onboardingValue == 'true';

    final token = await _api.getToken();
    final firebaseUser = _firebaseAuthService.currentUser;
    _setFirebaseUser(firebaseUser);

    if (token == null) {
      if (firebaseUser != null) {
        if (_firebaseAuthService.requiresEmailVerification(firebaseUser)) {
          _status = AuthStatus.emailVerificationRequired;
          notifyListeners();
          return;
        }

        try {
          await _completeFirebaseSession(firebaseUser, notifyAtEnd: false);
        } catch (e) {
          _errorMessage = 'Session restore failed: $e';
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        }
      }
      return;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException('Invalid JWT');

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      final wallet = data['walletAddress'] as String?;
      final identity = data['sub'] as String?;
      final firebaseUid = data['firebaseUid'] as String?;
      final email = data['email'] as String?;
      final displayName = data['displayName'] as String?;

      if (wallet != null && !_evmRegex.hasMatch(wallet)) {
        await _api.clearToken();
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _identityHash = identity;
      _walletAddress = wallet;
      _firebaseUid = firebaseUid ?? _firebaseUid;
      _email = email ?? _email;
      _displayName = displayName ?? _displayName;

      // Keep DE1057 as-is on restore so pool membership and auth stay correct.
      // Do not replace with MetaMask address.

      if (_walletAddress != null && _walletAddress!.isNotEmpty) {
        _status = AuthStatus.walletBound;
      } else {
        _status = AuthStatus.authenticated;
      }

      if (!_hasCompletedOnboarding) {
        await completeOnboarding();
      }
    } catch (_) {
      await _api.clearToken();
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    await _firebaseAuthService.signOut();
    await _walletService.disconnect();
    _status = AuthStatus.unauthenticated;
    _identityHash = null;
    _walletAddress = null;
    _firebaseUid = null;
    _email = null;
    _displayName = null;
    _photoUrl = null;
    notifyListeners();
  }

  void _applyStoredProfile(StoredProfilePreferences preferences) {
    _profileDisplayName = preferences.displayName;
    _profilePhoneNumber = preferences.phoneNumber;
    _avatarBase64 = preferences.avatarBase64;
    _requireTransactionConfirmation =
        preferences.requireTransactionConfirmation;
    _rememberedWallets = List<StoredWalletSlot>.from(preferences.walletSlots)
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  void _setFirebaseUser(User? user) {
    if (user == null) {
      return;
    }
    _firebaseUid = user.uid;
    _email = user.email ?? _email;
    _displayName = user.displayName ?? _displayName;
    _photoUrl = user.photoURL ?? _photoUrl;
  }

  Future<void> _completeFirebaseSession(
    User user, {
    bool notifyAtEnd = true,
  }) async {
    final idToken = await _firebaseAuthService.getIdToken(forceRefresh: true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Unable to read the Firebase ID token.');
    }

    try {
      final response = await _api.firebaseSession(idToken);
      await _applyAuthenticatedSession(
        response,
        firebaseUser: user,
        notifyAtEnd: false,
      );
    } catch (error) {
      if (!_shouldUseLocalFirebaseFallback(error)) {
        rethrow;
      }

      debugPrint(
        'Firebase session exchange unavailable. Falling back to local Firebase session: $error',
      );

      await _api.clearToken();
      await _applyAuthenticatedSession(
        _createLocalFirebaseSession(user),
        firebaseUser: user,
        notifyAtEnd: false,
      );
    }

    if (!_hasCompletedOnboarding) {
      await completeOnboarding();
    }

    if (notifyAtEnd) {
      notifyListeners();
    }
  }

  bool _shouldUseLocalFirebaseFallback(Object error) {
    if (error is! DioException) {
      return false;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        return statusCode == 503 || statusCode >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  Map<String, dynamic> _createLocalFirebaseSession(User user) {
    return {
      'identityHash': _localFirebaseIdentityHash(user),
      'walletAddress': null,
      'walletBindingStatus': 'unbound',
      'firebaseUid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'emailVerified': user.emailVerified,
    };
  }

  String _localFirebaseIdentityHash(User user) {
    final source = 'firebase:${user.uid}';
    final bytes = utf8.encode(source);
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final normalized = hex.length >= 64
        ? hex.substring(0, 64)
        : (hex + '0' * (64 - hex.length));
    return '0x$normalized';
  }

  Future<void> _applyAuthenticatedSession(
    Map<String, dynamic> response, {
    User? firebaseUser,
    bool notifyAtEnd = true,
  }) async {
    final accessToken = response['accessToken'] as String?;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _api.saveToken(accessToken);
    }

    _identityHash = response['identityHash'] as String?;
    final walletAddress = response['walletAddress'] as String?;
    _walletAddress =
        (walletAddress == null || walletAddress.isEmpty) ? null : walletAddress;
    _firebaseUid =
        response['firebaseUid'] as String? ?? firebaseUser?.uid ?? _firebaseUid;
    _email = response['email'] as String? ?? firebaseUser?.email ?? _email;
    _displayName = response['displayName'] as String? ??
        firebaseUser?.displayName ??
        _displayName;
    _photoUrl =
        response['photoUrl'] as String? ?? firebaseUser?.photoURL ?? _photoUrl;
    _status = _walletAddress != null && _walletAddress!.isNotEmpty
        ? AuthStatus.walletBound
        : AuthStatus.authenticated;
    _errorMessage = null;

    if (_walletAddress != null && _walletAddress!.isNotEmpty) {
      await _rememberWallet(_walletAddress!);
    }

    if (notifyAtEnd) {
      notifyListeners();
    }
  }

  StoredProfilePreferences _currentStoredProfile() {
    return StoredProfilePreferences(
      displayName: _profileDisplayName,
      phoneNumber: _profilePhoneNumber,
      avatarBase64: _avatarBase64,
      requireTransactionConfirmation: _requireTransactionConfirmation,
      walletSlots: _rememberedWallets,
    );
  }

  Future<void> _persistStoredProfile() async {
    final saved = await _profilePreferencesService.save(_currentStoredProfile());
    _applyStoredProfile(saved);
  }

  Future<void> _rememberWallet(
    String walletAddress, {
    String? preferredLabel,
  }) async {
    final trimmed = walletAddress.trim();
    if (trimmed.isEmpty || !_evmRegex.hasMatch(trimmed)) {
      return;
    }

    final normalized = trimmed.toLowerCase();
    final label = preferredLabel?.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingIndex = _rememberedWallets.indexWhere(
      (slot) => slot.address.toLowerCase() == normalized,
    );

    final updated = List<StoredWalletSlot>.from(_rememberedWallets);
    if (existingIndex >= 0) {
      final existing = updated.removeAt(existingIndex);
      updated.insert(
        0,
        existing.copyWith(
          address: trimmed,
          label: label != null && label.isNotEmpty ? label : existing.label,
          lastUsedAt: now,
        ),
      );
    } else {
      updated.insert(
        0,
        StoredWalletSlot(
          address: trimmed,
          label: label != null && label.isNotEmpty ? label : null,
          lastUsedAt: now,
        ),
      );
    }

    _rememberedWallets = updated.take(6).toList(growable: false);
    await _persistStoredProfile();
  }
}
