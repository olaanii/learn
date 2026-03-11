import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// API base URL priority:
  /// 1) `--dart-define=API_BASE_URL=...`
  /// 2) Web default (`/api`) for same-origin deployments
  /// 3) Non-web release fallback (`equb-db`)
  /// 4) Local dev fallback
  static String get apiBaseUrl {
    final configured = _apiBaseUrlFromEnv.trim();
    if (configured.isNotEmpty) {
      return _normalizeApiBaseUrl(configured);
    }
    if (kIsWeb) {
      return _normalizeApiBaseUrl('/api');
    }
    if (kReleaseMode) {
      return _normalizeApiBaseUrl('https://equb-db.vercel.app/api');
    }
    return _normalizeApiBaseUrl('http://localhost:3001/api');
  }

  static String _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.endsWith('/')) {
      return trimmed;
    }
    return '$trimmed/';
  }

  static const String rpcUrl = String.fromEnvironment(
    'RPC_URL',
    defaultValue: 'https://rpc.cc3-testnet.creditcoin.network',
  );

  /// Creditcoin chain ID. Testnet = 102031, Mainnet = 102030.
  static const int chainId = int.fromEnvironment(
    'CHAIN_ID',
    defaultValue: 102031,
  );

  static const String appName = 'Diaspora Equb';

  /// Block explorer URL — switches based on chain ID.
  static String get explorerUrl => chainId == 102030
      ? 'https://creditcoin.blockscout.com'
      : 'https://creditcoin-testnet.blockscout.com';

  /// Human-readable network label.
  static String get networkName =>
      isMainnet ? 'Creditcoin Mainnet' : 'Creditcoin Testnet';

  /// Whether we are targeting mainnet (useful for UI badges / warnings).
  static bool get isMainnet => chainId == 102030;

  /// Native token symbol based on compile-time chain ID.
  /// Prefer NetworkProvider.nativeSymbol at runtime for dynamic switching.
  static String get nativeSymbol => isMainnet ? 'CTC' : 'tCTC';

  /// USDC token address. Override via --dart-define=TEST_USDC_ADDRESS=0x...
  static const String usdcAddress = String.fromEnvironment(
    'TEST_USDC_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  /// USDT token address. Override via --dart-define=TEST_USDT_ADDRESS=0x...
  static const String usdtAddress = String.fromEnvironment(
    'TEST_USDT_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  /// Set to true to bypass Fayda e-ID verification during testing.
  /// This skips the onboarding flow and goes straight to the dashboard
  /// with a mock identity and wallet address.
  static const bool devBypassFayda = bool.fromEnvironment(
    'DEV_BYPASS_FAYDA',
    defaultValue: false,
  );

  /// Privy application ID from the Privy dashboard.
  /// Override via --dart-define=PRIVY_APP_ID=...
  static const String privyAppId = String.fromEnvironment(
    'PRIVY_APP_ID',
    defaultValue: '',
  );

  /// Privy client ID from the Privy dashboard.
  /// Override via --dart-define=PRIVY_APP_CLIENT_ID=...
  static const String privyAppClientId = String.fromEnvironment(
    'PRIVY_APP_CLIENT_ID',
    defaultValue: '',
  );

  /// Sentry DSN for Flutter error tracking (optional).
  /// Override via --dart-define=SENTRY_DSN=...
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
}
