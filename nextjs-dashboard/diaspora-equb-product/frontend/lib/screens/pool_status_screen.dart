import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/pool_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_service.dart';
import '../config/theme.dart';
import '../config/app_config.dart';

class PoolStatusScreen extends StatefulWidget {
  final String poolId;
  const PoolStatusScreen({super.key, required this.poolId});

  @override
  State<PoolStatusScreen> createState() => _PoolStatusScreenState();
}

class _PoolStatusScreenState extends State<PoolStatusScreen> {
  Map<String, dynamic>? _tokenInfo;
  bool _isContributing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoolData();
    });
  }

  Future<void> _loadPoolData() async {
    final pools = context.read<PoolProvider>();
    await pools.loadPool(widget.poolId);

    final info = await pools.getPoolTokenInfo(widget.poolId);
    if (mounted) {
      setState(() => _tokenInfo = info);
    }
  }

  bool get _isErc20Pool {
    if (_tokenInfo == null) return false;
    return _tokenInfo!['isErc20'] == true;
  }

  String get _tokenSymbol {
    if (!_isErc20Pool || _tokenInfo?['token'] == null) return 'CTC';
    return _tokenInfo!['token']['symbol'] ?? 'TOKEN';
  }

  String? get _tokenAddress {
    if (!_isErc20Pool || _tokenInfo?['token'] == null) return null;
    return _tokenInfo!['token']['address'];
  }

  Future<void> _contributeOnChain(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    final contributionAmount = pool['contributionAmount'] ?? '0';

    if (onChainPoolId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pool has no on-chain ID yet.'),
          ),
        );
      }
      return;
    }

    setState(() => _isContributing = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isErc20Pool
                ? 'Step 1/2: Approve $_tokenSymbol spending — confirm in wallet...'
                : 'Contributing $contributionAmount — confirm in your wallet...',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    String? txHash;

    if (_isErc20Pool && _tokenAddress != null) {
      txHash = await pools.approveAndContribute(
        onChainPoolId: onChainPoolId as int,
        contributionAmount: contributionAmount.toString(),
        tokenAddress: _tokenAddress!,
      );
    } else {
      txHash = await pools.buildAndSignContribute(
        onChainPoolId as int,
        contributionAmount.toString(),
        tokenAddress: _tokenAddress,
        poolId: widget.poolId,
      );
    }

    if (!mounted) return;
    setState(() => _isContributing = false);

    if (txHash != null) {
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context.read<WalletProvider>().refreshAfterTx(
              auth.walletAddress!,
            );
      }
      if (!mounted) return;
      await pools.loadPool(widget.poolId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contribution confirmed! TX: ${txHash.substring(0, 16)}...'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              debugPrint('${AppConfig.explorerUrl}/tx/$txHash');
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pools.errorMessage ?? 'Contribution failed or rejected'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _contributeLegacy(
    PoolProvider pools,
    String walletAddress,
    Map<String, dynamic> pool,
  ) async {
    final round = pool['currentRound'] ?? 1;
    final success = await pools.contribute(
      widget.poolId,
      walletAddress,
      round,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Contribution recorded for round $round!'
              : pools.errorMessage ?? 'Contribution failed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pools = context.watch<PoolProvider>();
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletService>();
    final walletProvider = context.watch<WalletProvider>();
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
                onRefresh: _loadPoolData,
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
                            _buildInfoRow('Current Round',
                                '${pool['currentRound'] ?? 1}'),
                            _buildInfoRow('Treasury',
                                _truncateAddress(pool['treasury'] ?? '')),
                            if (pool['onChainPoolId'] != null)
                              _buildInfoRow('On-Chain ID',
                                  '${pool['onChainPoolId']}'),
                            if (_isErc20Pool)
                              _buildInfoRow('Token', '$_tokenSymbol ($_tokenAddress)'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Balance card showing deduction preview
                    if (auth.walletAddress != null && wallet.isConnected) ...[
                      _buildBalancePreviewCard(walletProvider, pool),
                      const SizedBox(height: 16),
                    ],

                    // Members section
                    Text(
                      'Members (${(pool['members'] as List?)?.length ?? 0}/${pool['maxMembers'] ?? 0})',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 8),
                    ...((pool['members'] as List?) ?? [])
                        .map<Widget>((member) {
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
                              color: isCurrentUser
                                  ? Colors.white
                                  : Colors.grey[600],
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

                    // Contribute buttons
                    if (auth.walletAddress != null) ...[
                      if (wallet.isConnected &&
                          pool['onChainPoolId'] != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_isContributing || pools.isLoading)
                                ? null
                                : () => _contributeOnChain(pools, wallet, pool),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkButton,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: _isContributing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isErc20Pool
                                            ? 'Approve & Contribute $_tokenSymbol (Round ${pool['currentRound'] ?? 1})'
                                            : 'Contribute On-Chain (Round ${pool['currentRound'] ?? 1})',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isErc20Pool
                              ? 'Two wallet signatures required: approve $_tokenSymbol spend, then contribute.'
                              : 'Your wallet (MetaMask) will pop up to sign this transaction.',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _contributeLegacy(
                            pools,
                            auth.walletAddress!,
                            pool,
                          ),
                          icon: const Icon(Icons.payment),
                          label: Text(
                            'Contribute to Round ${pool['currentRound'] ?? 1}',
                          ),
                        ),
                        if (!wallet.isConnected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Connect WalletConnect for on-chain contributions',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ],

                    // Last TX hash
                    if (pools.lastTxHash != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppTheme.successColor.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: AppTheme.successColor),
                          title: const Text('Last Transaction'),
                          subtitle: Text(
                            pools.lastTxHash!,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBalancePreviewCard(
      WalletProvider walletProvider, Map<String, dynamic> pool) {
    final contributionRaw = pool['contributionAmount']?.toString() ?? '0';
    final contribution = double.tryParse(contributionRaw) ?? 0;

    String currentBalance;
    String afterBalance;

    if (_isErc20Pool) {
      final bal =
          double.tryParse(walletProvider.balanceOf(_tokenSymbol)) ?? 0;
      currentBalance = bal.toStringAsFixed(2);
      afterBalance = (bal - contribution).toStringAsFixed(2);
    } else {
      final bal = double.tryParse(walletProvider.balance) ?? 0;
      currentBalance = bal.toStringAsFixed(2);
      afterBalance = (bal - contribution).toStringAsFixed(2);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(
          color: AppTheme.accentYellow,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '\$$currentBalance ${_isErc20Pool ? _tokenSymbol : 'CTC'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contribution',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.negative,
                ),
              ),
              Text(
                '-$contributionRaw',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.negative,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'After Contribution',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\$$afterBalance',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}
