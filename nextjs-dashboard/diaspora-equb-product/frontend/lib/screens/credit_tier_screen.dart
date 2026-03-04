import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/network_provider.dart';
import '../config/theme.dart';

class CreditTierScreen extends StatefulWidget {
  const CreditTierScreen({super.key});

  @override
  State<CreditTierScreen> createState() => _CreditTierScreenState();
}

class _CreditTierScreenState extends State<CreditTierScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        context.read<CreditProvider>().loadTierEligibility(auth.walletAddress!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final credit = context.watch<CreditProvider>();

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Credit & Tiers'),
        ),
      body: credit.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Credit Score Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Your Credit Score',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor(context),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${credit.score}',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: credit.score >= 0
                                    ? AppTheme.successColor
                                    : AppTheme.dangerColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          credit.score >= 50
                              ? 'Elite Status'
                              : credit.score >= 20
                                  ? 'Proven Saver'
                                  : credit.score >= 5
                                      ? 'Growing Trust'
                                      : 'Getting Started',
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Current Tier Card
                Text(
                  'Current Tier',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _buildCurrentTierCard(context, credit),
                const SizedBox(height: 24),

                // All Tiers
                Text(
                  'Tier Progression',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),

                Builder(builder: (context) {
                  final sym = context.read<NetworkProvider>().nativeSymbol;
                  return Column(children: [
                    _buildTierCard(context, 0, 'Starter', '1 $sym', 'None',
                        'Score >= 0', credit.eligibleTier >= 0),
                    _buildTierCard(context, 1, 'Growing', '10 $sym', '10%',
                        'Score >= 5', credit.eligibleTier >= 1),
                    _buildTierCard(context, 2, 'Proven', '50 $sym', '5%',
                        'Score >= 20', credit.eligibleTier >= 2),
                    _buildTierCard(context, 3, 'Elite', '200 $sym', '2%',
                        'Score >= 50', credit.eligibleTier >= 3),
                  ]);
                }),

                const SizedBox(height: 24),

                // How scoring works
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'How Scoring Works',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildScoringRow('+1', 'Contributing on time'),
                        _buildScoringRow(
                            '-10', 'Missing a contribution (default)'),
                        _buildScoringRow(
                            'Frozen', 'Payout stream frozen on default'),
                        _buildScoringRow(
                            'Slashed', 'Collateral slashed to compensate equb'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildCurrentTierCard(BuildContext context, CreditProvider credit) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${credit.eligibleTier}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Max Equb Size: ${credit.maxPoolSize} wei',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
            Text(
              'Collateral Rate: ${credit.collateralRate ~/ 100}%',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
            if (credit.nextTier != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: credit.scoreForNextTier != null &&
                          credit.scoreForNextTier! > 0
                      ? (credit.score / credit.scoreForNextTier!)
                          .clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: AppTheme.textHintColor(context),
                  color: AppTheme.primaryColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${credit.score} / ${credit.scoreForNextTier} points for Tier ${credit.nextTier}',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, int tier, String name,
      String maxPool, String collateral, String requirement, bool unlocked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: unlocked ? AppTheme.successColor : AppTheme.textTertiaryColor(context),
          child: Text(
            '$tier',
            style: TextStyle(
              color: unlocked ? Colors.white : AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'Tier $tier - $name',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: unlocked ? null : AppTheme.textTertiaryColor(context),
          ),
        ),
        subtitle: Text('Max: $maxPool | Collateral: $collateral'),
        trailing: unlocked
            ? const Icon(Icons.check_circle, color: AppTheme.successColor)
            : Icon(Icons.lock, color: AppTheme.textTertiaryColor(context)),
      ),
    );
  }

  Widget _buildScoringRow(String points, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              points,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: points.startsWith('+')
                    ? AppTheme.successColor
                    : points.startsWith('-')
                        ? AppTheme.dangerColor
                        : AppTheme.warningColor,
              ),
            ),
          ),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
