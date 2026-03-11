import 'package:flutter/material.dart';

import '../config/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Help & Support')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: const [
            _SupportHero(),
            SizedBox(height: 16),
            _SupportCard(
              icon: Icons.flag_circle_outlined,
              eyebrow: 'Getting started',
              title: 'Need help with onboarding?',
              body:
                  'Complete onboarding first, then continue with email/password or Google sign-in. If email verification is required, finish that before the app session is activated.',
              footer:
                  'Best next step: finish onboarding, then return to the auth screen.',
            ),
            SizedBox(height: 16),
            _SupportCard(
              icon: Icons.account_balance_wallet_outlined,
              eyebrow: 'Wallet setup',
              title: 'Wallet connection',
              body:
                'Wallet connection is optional during setup. On mobile, you can create or restore a Privy embedded wallet later from Profile. Web and desktop can still use manual wallet binding where needed.',
              footer:
                  'Use Profile to manage connected wallets, bound wallets, and saved wallet slots.',
            ),
            SizedBox(height: 16),
            _SupportCard(
              icon: Icons.shield_outlined,
              eyebrow: 'Protection',
              title: 'Security controls',
              body:
                  'The Security screen lets you configure authenticator-app 2FA, biometric unlock, trusted devices, and transaction confirmation preferences once a wallet is linked.',
              footer:
                  'Security becomes fully available after one wallet is bound to the account.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.support_agent_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support desk',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use this screen as the quick orientation point for onboarding, wallet setup, and account protection.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final String footer;

  const _SupportCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eyebrow,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textTertiaryColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              footer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
