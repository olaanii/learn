import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/pool_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class PoolStatusScreen extends StatefulWidget {
  final String poolId;
  const PoolStatusScreen({super.key, required this.poolId});

  @override
  State<PoolStatusScreen> createState() => _PoolStatusScreenState();
}

class _PoolStatusScreenState extends State<PoolStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoolProvider>().loadPool(widget.poolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pools = context.watch<PoolProvider>();
    final auth = context.watch<AuthProvider>();
    final pool = pools.selectedPool;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Pool Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payment),
            tooltip: 'View Payout Stream',
            onPressed: () => context.push('/payouts/${widget.poolId}'),
          ),
        ],
      ),
      body: pool == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  context.read<PoolProvider>().loadPool(widget.poolId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Pool header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tier ${pool['tier'] ?? 0}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  pool['status'] ?? 'pending',
                                  style: const TextStyle(
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow('Contribution',
                              '${pool['contributionAmount'] ?? '0'} wei'),
                          _buildInfoRow(
                              'Current Round', '${pool['currentRound'] ?? 1}'),
                          _buildInfoRow('Treasury',
                              _truncateAddress(pool['treasury'] ?? '')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Members section
                  Text(
                    'Members (${(pool['members'] as List?)?.length ?? 0}/${pool['maxMembers'] ?? 0})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...((pool['members'] as List?) ?? []).map<Widget>((member) {
                    final address = member['walletAddress'] ?? '';
                    final isCurrentUser = address == auth.walletAddress;
                    return Card(
                      color: isCurrentUser
                          ? AppTheme.primaryColor.withValues(alpha: 0.05)
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentUser
                              ? AppTheme.primaryColor
                              : Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            color:
                                isCurrentUser ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          _truncateAddress(address),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        subtitle: Text(
                          isCurrentUser ? 'You' : 'Member',
                          style: TextStyle(
                            color: isCurrentUser
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Contribute button
                  if (auth.walletAddress != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final round = pool['currentRound'] ?? 1;
                        final success = await pools.contribute(
                          widget.poolId,
                          auth.walletAddress!,
                          round,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Contribution recorded for round $round!'
                                  : pools.errorMessage ??
                                      'Contribution failed'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.payment),
                      label: Text(
                          'Contribute to Round ${pool['currentRound'] ?? 1}'),
                    ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}
