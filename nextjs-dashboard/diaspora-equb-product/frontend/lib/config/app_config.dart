class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Creditcoin RPC endpoint. Override via --dart-define=RPC_URL=...
  /// Testnet: https://rpc.cc3-testnet.creditcoin.network  (102031)
  /// Mainnet: https://mainnet3.creditcoin.network          (102030)
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

  /// Whether we are targeting mainnet (useful for UI badges / warnings).
  static bool get isMainnet => chainId == 102030;

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

  /// WalletConnect project ID from https://cloud.walletconnect.com
  /// Required for WalletConnect v2 pairing.
  /// Override via --dart-define=WALLETCONNECT_PROJECT_ID=...
  static const String walletConnectProjectId = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
    defaultValue: '',
  );

  /// Sentry DSN for Flutter error tracking (optional).
  /// Override via --dart-define=SENTRY_DSN=...
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
}
