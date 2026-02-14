import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pool_provider.dart';
import '../providers/credit_provider.dart';
import '../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.walletAddress != null) {
      await Future.wait([
        context.read<PoolProvider>().loadPools(),
        context.read<CreditProvider>().loadTierEligibility(auth.walletAddress!),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pools = context.watch<PoolProvider>();
    final credit = context.watch<CreditProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diaspora Equb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome header
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (auth.walletAddress != null)
              Text(
                auth.walletAddress!.length > 36
                    ? '${auth.walletAddress!.substring(0, 8)}...${auth.walletAddress!.substring(36)}'
                    : auth.walletAddress!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(height: 24),

            // Credit Score & Tier Card
            _buildCreditCard(context, credit),
            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.search,
                    label: 'Browse Pools',
                    onTap: () => context.push('/pools'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.star,
                    label: 'Credit & Tiers',
                    onTap: () => context.push('/credit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Active Pools
            Text(
              'Your Pools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            if (pools.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (pools.pools.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.group_add, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No active pools',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/pools'),
                        child: const Text('Browse available pools'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...pools.pools.map((pool) => _buildPoolCard(context, pool)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard(BuildContext context, CreditProvider credit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit Score',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      '${credit.score}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: credit.score >= 0
                                    ? AppTheme.successColor
                                    : AppTheme.dangerColor,
                              ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tier ${credit.eligibleTier}',
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (credit.nextTier != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: credit.scoreForNextTier != null &&
                        credit.scoreForNextTier! > 0
                    ? (credit.score / credit.scoreForNextTier!).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: Colors.grey[200],
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                'Score ${credit.score}/${credit.scoreForNextTier} for Tier ${credit.nextTier}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoolCard(BuildContext context, Map<String, dynamic> pool) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/pools/${pool['id']}'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Text(
            'T${pool['tier'] ?? 0}',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title:
            Text('Pool ${(pool['id'] as String?)?.substring(0, 8) ?? ''}...'),
        subtitle: Text(
          'Round ${pool['currentRound'] ?? 1} / ${pool['maxMembers'] ?? 0} members',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: pool['status'] == 'active'
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pool['status'] ?? 'pending',
            style: TextStyle(
              fontSize: 12,
              color: pool['status'] == 'active'
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
          ),
        ),
      ),
    );
  }
}
