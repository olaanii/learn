class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Creditcoin Testnet RPC. Override via --dart-define=RPC_URL=...
  static const String rpcUrl = String.fromEnvironment(
    'RPC_URL',
    defaultValue: 'https://rpc.cc3-testnet.creditcoin.network',
  );

  /// Creditcoin Testnet chain ID = 102031 (mainnet = 102030)
  static const int chainId = int.fromEnvironment(
    'CHAIN_ID',
    defaultValue: 102031,
  );

  static const String appName = 'Diaspora Equb';

  /// Creditcoin Testnet block explorer
  static const String explorerUrl = 'https://creditcoin-testnet.blockscout.com';

  /// Test USDC address on Creditcoin testnet (deployed by you)
  /// Override via --dart-define=TEST_USDC_ADDRESS=0x...
  static const String usdcAddress = String.fromEnvironment(
    'TEST_USDC_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  /// Test USDT address on Creditcoin testnet (deployed by you)
  static const String usdtAddress = String.fromEnvironment(
    'TEST_USDT_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  /// Set to true to bypass Fayda e-ID verification during testing.
  /// This skips the onboarding flow and goes straight to the dashboard
  /// with a mock identity and wallet address.
  static const bool devBypassFayda = bool.fromEnvironment(
    'DEV_BYPASS_FAYDA',
    defaultValue: true,
  );
}
