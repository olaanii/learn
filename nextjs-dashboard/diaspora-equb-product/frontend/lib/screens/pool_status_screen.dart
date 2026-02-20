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
  bool _isClosingRound = false;
  bool _isSchedulingStream = false;

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

  /// True if the user is the pool admin: only the wallet that signed pool creation (createdBy).
  /// Treasury does not define admin; only the creation signer does.
  bool _isPoolAdmin(Map<String, dynamic> pool, String? authAddress, String? connectedAddress) {
    final createdBy = pool['createdBy']?.toString().trim();
    if (createdBy == null || createdBy.isEmpty) return false;
    const zero = '0x0000000000000000000000000000000000000000';
    if (createdBy.toLowerCase() == zero) return false;
    final creatorLower = createdBy.toLowerCase();
    bool match(String? addr) {
      if (addr == null || addr.isEmpty) return false;
      return addr.toLowerCase().trim() == creatorLower;
    }
    return match(authAddress) || match(connectedAddress);
  }

  Future<void> _closeRound(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    if (onChainPoolId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pool has no on-chain ID yet.')),
        );
      }
      return;
    }
    setState(() => _isClosingRound = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing round — confirm in your wallet...'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    final txHash = await pools.buildAndSignCloseRound(onChainPoolId as int);
    if (!mounted) return;
    setState(() => _isClosingRound = false);
    if (txHash != null) {
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context.read<WalletProvider>().refreshAfterTx(auth.walletAddress!);
      }
      await pools.loadPool(widget.poolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Round closed. TX: ${txHash.substring(0, 16)}...'),
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
          content: Text(pools.errorMessage ?? 'Close round failed or rejected'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _schedulePayoutForWinner(
    PoolProvider pools,
    Map<String, dynamic> pool,
    String beneficiaryAddress,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    if (onChainPoolId == null) return;
    final contributionStr = pool['contributionAmount']?.toString() ?? '0';
    final contribWei = int.tryParse(contributionStr) ?? 0;
    final members = pool['members'] as List? ?? [];
    final memberCount = members.length;
    if (memberCount == 0) return;
    const upfrontPercent = 20;
    final maxMembers = pool['maxMembers'] ?? 10;
    final totalRounds = maxMembers;
    final totalWei = contribWei * memberCount;
    final total = totalWei.toString();

    setState(() => _isSchedulingStream = true);
    final txHash = await pools.buildAndSignScheduleStream(
      onChainPoolId: onChainPoolId as int,
      beneficiary: beneficiaryAddress,
      total: total,
      upfrontPercent: upfrontPercent,
      totalRounds: totalRounds,
    );
    if (!mounted) return;
    setState(() => _isSchedulingStream = false);
    if (txHash != null) {
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context.read<WalletProvider>().refreshAfterTx(auth.walletAddress!);
      }
      await pools.loadPool(widget.poolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payout scheduled for ${_truncateAddress(beneficiaryAddress)}. TX: ${txHash.substring(0, 16)}...',
          ),
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
          content: Text(
            pools.errorMessage ?? 'Schedule payout failed or rejected',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showSelectWinnerDialog(
    BuildContext context,
    PoolProvider pools,
    Map<String, dynamic> pool,
    String memberAddress,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule payout for winner'),
        content: Text(
          'Schedule the round payout for ${_truncateAddress(memberAddress)}? '
          'They will receive the upfront amount (20%) plus streamed payouts over the remaining rounds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _schedulePayoutForWinner(pools, pool, memberAddress);
            },
            child: const Text('Schedule payout'),
          ),
        ],
      ),
    );
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
      final err = pools.errorMessage ?? 'Contribution failed or rejected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$err\nTip: Join the pool first, contribute once per round, and use the Contribute button (not a direct send to the pool address).',
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
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
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh pool (e.g. after on-chain creation)',
              onPressed: () async {
                await _loadPoolData();
              },
            ),
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
                child: Builder(
                  builder: (context) {
                    // Pool admin = who signed pool creation (createdBy) or treasury as fallback.
                    final isPoolAdmin = _isPoolAdmin(
                        pool, auth.walletAddress, wallet.walletAddress);
                    final canRunDraw = isPoolAdmin &&
                        pool['onChainPoolId'] != null &&
                        wallet.isConnected;
                    return ListView(
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
                            if (pool['createdBy'] != null &&
                                (pool['createdBy'] as String).isNotEmpty &&
                                (pool['createdBy'] as String).toLowerCase() !=
                                    '0x0000000000000000000000000000000000000000')
                              _buildInfoRow('Creator (pool admin)',
                                  _truncateAddress(pool['createdBy'] ?? '')),
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

                    // Pool admin: show for on-chain pools or when you are the creator
                    if (pool['onChainPoolId'] != null || isPoolAdmin) ...[
                      Card(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pool admin',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: canRunDraw && !_isClosingRound && !pools.isLoading
                                      ? () => _closeRound(pools, wallet, pool)
                                      : null,
                                  icon: _isClosingRound
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.flag_outlined, size: 20),
                                  label: Text(
                                    _isClosingRound
                                        ? 'Closing round...'
                                        : 'Close round ${pool['currentRound'] ?? 1}',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: const BorderSide(
                                        color: AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                canRunDraw
                                    ? 'After closing, pick a winner below and schedule their payout.'
                                    : 'Pick a winner below and schedule their payout (after closing the round).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (!canRunDraw) ...[
                                const SizedBox(height: 8),
                                if (!wallet.isConnected)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded,
                                            size: 18, color: AppTheme.warningColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Connect your wallet to enable Close round and Select as winner.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (wallet.isConnected && !isPoolAdmin)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline,
                                            size: 18, color: AppTheme.warningColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Only the wallet that signed pool creation can close rounds and pick winners. Connect that wallet (creator) to enable these actions.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                      final canSelectWinner = canRunDraw && !_isSchedulingStream;
                      final showWinnerButton = pool['onChainPoolId'] != null || isPoolAdmin;
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
                          trailing: showWinnerButton
                              ? TextButton.icon(
                                  onPressed: canSelectWinner
                                      ? () => _showSelectWinnerDialog(
                                            context,
                                            pools,
                                            pool,
                                            address,
                                          )
                                      : null,
                                  icon: const Icon(Icons.emoji_events_outlined,
                                      size: 18),
                                  label: const Text('Select as winner'),
                                )
                              : null,
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
                        const SizedBox(height: 6),
                        Text(
                          'To add tCTC: use the Contribute button only. You must be a pool member first (Join pool). Do not send tCTC directly to the pool address—it will fail.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
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
                );
                  },
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
