import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/pool_provider.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../config/theme.dart';

class PoolBrowserScreen extends StatefulWidget {
  const PoolBrowserScreen({super.key});

  @override
  State<PoolBrowserScreen> createState() => _PoolBrowserScreenState();
}

class _PoolBrowserScreenState extends State<PoolBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tierLabels = [
    'All',
    'Tier 0',
    'Tier 1',
    'Tier 2',
    'Tier 3'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tierLabels.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoolProvider>().loadPools();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tier = _tabController.index == 0 ? null : _tabController.index - 1;
    context.read<PoolProvider>().loadPools(tier: tier);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pools = context.watch<PoolProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Browse Pools'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: _tierLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: pools.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pools.pools.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pool, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No pools available',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Create one to get started!',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pools.pools.length,
                  itemBuilder: (context, index) {
                    final pool = pools.pools[index];
                    return _buildPoolCard(context, pool);
                  },
                ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreatePoolDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Create Pool'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPoolCard(BuildContext context, Map<String, dynamic> pool) {
    final memberCount = (pool['members'] as List?)?.length ?? 0;
    final maxMembers = pool['maxMembers'] ?? 0;
    final tier = pool['tier'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/pools/${pool['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tier $tier',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Round ${pool['currentRound'] ?? 1}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Contribution: ${pool['contributionAmount'] ?? '0'} wei',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$memberCount / $maxMembers members',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: memberCount < maxMembers
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      memberCount < maxMembers ? 'Open' : 'Full',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: memberCount < maxMembers
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: maxMembers > 0 ? memberCount / maxMembers : 0,
                backgroundColor: Colors.grey[200],
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePoolDialog(BuildContext context) {
    final tierController = TextEditingController(text: '0');
    final contributionController = TextEditingController();
    final membersController = TextEditingController();
    final treasuryController = TextEditingController();
    final wallet = context.read<WalletService>();
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Pool'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tierController,
                decoration: const InputDecoration(labelText: 'Tier (0-3)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contributionController,
                decoration:
                    const InputDecoration(labelText: 'Contribution (wei)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: membersController,
                decoration:
                    const InputDecoration(labelText: 'Max Members (2-50)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: treasuryController,
                decoration: const InputDecoration(
                    labelText: 'Treasury Address (0x...)'),
              ),
              if (!wallet.isConnected)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Connect your wallet to create on-chain pools.',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (wallet.isConnected) {
                Navigator.pop(ctx);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Creating pool — confirm in your wallet...'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }

                final txHash = await context.read<PoolProvider>().buildAndSignCreatePool(
                  tier: int.tryParse(tierController.text) ?? 0,
                  contributionAmount: contributionController.text,
                  maxMembers: int.tryParse(membersController.text) ?? 5,
                  treasury: treasuryController.text.isNotEmpty
                      ? treasuryController.text
                      : auth.walletAddress ?? '0x0000000000000000000000000000000000000000',
                );

                if (context.mounted) {
                  if (txHash != null) {
                    await context.read<PoolProvider>().loadPools();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pool created on-chain! TX: ${txHash.substring(0, 16)}...'),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.read<PoolProvider>().errorMessage ?? 'Pool creation failed',
                        ),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              } else {
                final pool = await context.read<PoolProvider>().createPool(
                  tier: int.tryParse(tierController.text) ?? 0,
                  contributionAmount: contributionController.text,
                  maxMembers: int.tryParse(membersController.text) ?? 5,
                  treasury: treasuryController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (pool != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pool created (DB-only, connect wallet for on-chain).')),
                  );
                }
              }
            },
            child: Text(wallet.isConnected ? 'Create & Sign' : 'Create'),
          ),
        ],
      ),
    );
  }
}
