import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _faydaTokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _faydaTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                const Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Diaspora Equb',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Decentralized Rotating Savings\nPowered by Creditcoin',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                _buildFeatureRow(Icons.verified_user, 'Identity Verified',
                    'Fayda e-ID or wallet-based login'),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.lock, 'Smart Contract Protected',
                    'Streamed payouts prevent exit scams'),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.trending_up, 'Build Credit On-Chain',
                    'Earn reputation with each round'),
                const SizedBox(height: 32),

                // Login mode tabs
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFFF7F8FA),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: AppTheme.textTertiary,
                          indicatorColor: AppTheme.primaryColor,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(text: 'Connect Wallet'),
                            Tab(text: 'Fayda e-ID'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildWalletTab(auth),
                            _buildFaydaTab(auth),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (AppConfig.devBypassFayda) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: auth.status == AuthStatus.loading
                        ? null
                        : () => auth.skipFaydaForTesting(),
                    icon: const Icon(Icons.developer_mode),
                    label: const Text('Dev: Skip to Test User'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  Text(
                    'Dev mode: bypass for local testing',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTab(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Start',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your MetaMask wallet to join an Equb pool on Creditcoin testnet.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const Spacer(),
          if (auth.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                auth.errorMessage!,
                style: const TextStyle(color: AppTheme.dangerColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton.icon(
            onPressed: auth.status == AuthStatus.loading
                ? null
                : () => auth.loginWithWalletOnly(),
            icon: auth.status == AuthStatus.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.account_balance_wallet),
            label: Text(
              auth.status == AuthStatus.loading
                  ? 'Connecting...'
                  : 'Connect Wallet',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaydaTab(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify with Fayda',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your Fayda e-ID token for full identity verification.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _faydaTokenController,
              decoration: const InputDecoration(
                labelText: 'Fayda Token',
                hintText: 'Enter your Fayda verification token',
                prefixIcon: Icon(Icons.fingerprint),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your Fayda token';
                }
                return null;
              },
            ),
            const Spacer(),
            if (auth.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  auth.errorMessage!,
                  style:
                      const TextStyle(color: AppTheme.dangerColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: auth.status == AuthStatus.loading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        await auth
                            .verifyFayda(_faydaTokenController.text.trim());
                      }
                    },
              icon: auth.status == AuthStatus.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(
                auth.status == AuthStatus.loading
                    ? 'Verifying...'
                    : 'Verify with Fayda',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
