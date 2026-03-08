import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

class DesktopLandingScreen extends StatelessWidget {
  const DesktopLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppTheme.buttonColor(context),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diaspora Equb',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Desktop workspace for modern savings circles',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/auth'),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor(context).withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                                border: AppTheme.borderFor(context, opacity: 0.06),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppTheme.buttonColor(context).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Desktop-first control center',
                                      style: textTheme.labelLarge?.copyWith(
                                        color: AppTheme.buttonColor(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    'Run your Equb workspace from one stable desktop layout.',
                                    style: textTheme.displayMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Track rounds, payouts, governance, profile, and wallet actions from a fixed navigation shell with room for larger grids, richer detail, and uninterrupted vertical browsing.',
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.textSecondaryColor(context),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: const [
                                      _LandingStatChip(label: 'Fixed desktop navigation'),
                                      _LandingStatChip(label: 'Wallet and notifications in one utility rail'),
                                      _LandingStatChip(label: 'Governance, rules, and payout views aligned for desktop'),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => context.go('/auth'),
                                        child: const Text('Open Workspace'),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        onPressed: () => context.go('/pools'),
                                        child: const Text('Explore Equbs'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: const [
                                Expanded(
                                  child: _LandingFeatureCard(
                                    icon: Icons.dashboard_customize_rounded,
                                    title: 'Structured desktop canvas',
                                    body: 'Large screens keep navigation fixed and push every operational screen into the main content pane instead of falling back to stacked mobile framing.',
                                  ),
                                ),
                                SizedBox(height: 20),
                                Expanded(
                                  child: _LandingFeatureCard(
                                    icon: Icons.account_balance_wallet_rounded,
                                    title: 'Wallet-aware workspace',
                                    body: 'Wallet connection state, notifications, and network status stay visible in the desktop utility area so action context is always available.',
                                  ),
                                ),
                                SizedBox(height: 20),
                                Expanded(
                                  child: _LandingFeatureCard(
                                    icon: Icons.hub_rounded,
                                    title: 'On-chain flow visibility',
                                    body: 'Round status, payouts, governance proposals, and rules all fit inside a consistent desktop shell for faster review and control.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingStatChip extends StatelessWidget {
  final String label;

  const _LandingStatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _LandingFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _LandingFeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.buttonColor(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.buttonColor(context)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}