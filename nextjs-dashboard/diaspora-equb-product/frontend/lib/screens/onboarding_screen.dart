import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tokenController.dispose();
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
              const SizedBox(height: 60),
              // Logo / Title
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
              const SizedBox(height: 48),

              // Feature highlights
              _buildFeatureRow(Icons.verified_user, 'Fayda e-ID Verified',
                  'Secure identity binding'),
              const SizedBox(height: 16),
              _buildFeatureRow(Icons.lock, 'Smart Contract Protected',
                  'Streamed payouts prevent exit scams'),
              const SizedBox(height: 16),
              _buildFeatureRow(Icons.trending_up, 'Build Credit On-Chain',
                  'Earn reputation with each round'),
              const SizedBox(height: 40),

              // Fayda verification form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Verify Your Identity',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your Fayda e-ID verification token to get started.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            labelText: 'Fayda Token',
                            hintText: 'Enter your Fayda verification token',
                            prefixIcon: Icon(Icons.fingerprint),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your Fayda token';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        if (auth.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              auth.errorMessage!,
                              style:
                                  const TextStyle(color: AppTheme.dangerColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ElevatedButton(
                          onPressed: auth.status == AuthStatus.loading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await auth.verifyFayda(
                                        _tokenController.text.trim());
                                  }
                                },
                          child: auth.status == AuthStatus.loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verify with Fayda'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dev bypass button (only shown when DEV_BYPASS_FAYDA is true)
              if (auth.isDevBypassEnabled) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => auth.skipFaydaForTesting(),
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Skip Fayda — Enter as Test User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                Text(
                  'Dev mode: Fayda verification is disabled',
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
