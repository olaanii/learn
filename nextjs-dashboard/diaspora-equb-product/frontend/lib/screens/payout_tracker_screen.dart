import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/pool_provider.dart';

class PayoutTrackerScreen extends StatefulWidget {
  final String poolId;
  const PayoutTrackerScreen({super.key, required this.poolId});

  @override
  State<PayoutTrackerScreen> createState() => _PayoutTrackerScreenState();
}

class _PayoutTrackerScreenState extends State<PayoutTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoolProvider>().loadPool(widget.poolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Payout Stream'),
        ),
        body: Consumer<PoolProvider>(
          builder: (context, poolProvider, _) {
            if (poolProvider.isLoading && poolProvider.selectedPool == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final pool = poolProvider.selectedPool;
            if (pool == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48,
                          color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        poolProvider.errorMessage ?? 'Pool not found',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Extract pool data
            final contributionAmount = double.tryParse(
                    pool['contributionAmount']?.toString() ?? '0') ??
                0;
            final maxMembers = pool['maxMembers'] ?? 10;
            final currentRound = pool['currentRound'] ?? 0;
            final totalRounds = maxMembers;
            final members = pool['members'] as List? ?? [];
            final memberCount = members.length;
            final totalAmount = contributionAmount * memberCount;
            const upfrontPercent = 20; // default 20%
            final upfrontAmount = totalAmount * upfrontPercent / 100;
            final streamAmount = totalAmount - upfrontAmount;
            final perRound = totalRounds > 0 ? streamAmount / totalRounds : 0.0;
            final releasedRounds = currentRound > 0 ? currentRound - 1 : 0;
            final totalReleased = upfrontAmount + (perRound * releasedRounds);
            final remaining = totalAmount - totalReleased;
            final status = pool['status']?.toString() ?? 'pending-onchain';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stream overview card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stream Overview',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        _buildStreamInfoRow('Total Amount',
                            '${totalAmount.toStringAsFixed(2)} USDC'),
                        _buildStreamInfoRow('Upfront ($upfrontPercent%)',
                            '${upfrontAmount.toStringAsFixed(2)} USDC'),
                        _buildStreamInfoRow(
                            'Per Round', '${perRound.toStringAsFixed(2)} USDC'),
                        _buildStreamInfoRow('Total Rounds', '$totalRounds'),
                        _buildStreamInfoRow('Released Rounds',
                            '$releasedRounds / $totalRounds'),
                        _buildStreamInfoRow(
                            'Members', '$memberCount / $maxMembers'),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        // Status
                        Row(
                          children: [
                            Icon(
                              status == 'active'
                                  ? Icons.check_circle
                                  : status == 'completed'
                                      ? Icons.verified
                                      : Icons.hourglass_top,
                              color: status == 'active'
                                  ? AppTheme.successColor
                                  : status == 'completed'
                                      ? AppTheme.primaryColor
                                      : AppTheme.warningColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status == 'active'
                                  ? 'Stream Active'
                                  : status == 'completed'
                                      ? 'Stream Completed'
                                      : 'Pending On-Chain',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Visual progress
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Release Progress',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Upfront section
                        _buildProgressSection(
                          context,
                          label: 'Upfront Payment',
                          amount: '${upfrontAmount.toStringAsFixed(2)} USDC',
                          isReleased: currentRound > 0,
                        ),
                        const SizedBox(height: 12),

                        // Round releases
                        for (int i = 1; i <= totalRounds; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildProgressSection(
                              context,
                              label: 'Round $i',
                              amount: '${perRound.toStringAsFixed(2)} USDC',
                              isReleased: i <= releasedRounds,
                              isCurrent: i == releasedRounds + 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Released total
                Card(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Released',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                              '${totalReleased.toStringAsFixed(2)} USDC',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Remaining',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                              '${remaining.toStringAsFixed(2)} USDC',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStreamInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    BuildContext context, {
    required String label,
    required String amount,
    bool isReleased = false,
    bool isCurrent = false,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReleased
                ? AppTheme.successColor
                : isCurrent
                    ? AppTheme.warningColor
                    : Colors.grey[300],
          ),
          child: Icon(
            isReleased
                ? Icons.check
                : isCurrent
                    ? Icons.hourglass_top
                    : Icons.circle,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isReleased ? Colors.grey[600] : null,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isReleased ? AppTheme.successColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
