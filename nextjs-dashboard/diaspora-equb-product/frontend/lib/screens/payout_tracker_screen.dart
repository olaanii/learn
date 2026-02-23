import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/pool_provider.dart';
import '../services/app_snackbar_service.dart';
import '../services/wallet_service.dart';

class PayoutTrackerScreen extends StatefulWidget {
  final String poolId;
  const PayoutTrackerScreen({super.key, required this.poolId});

  @override
  State<PayoutTrackerScreen> createState() => _PayoutTrackerScreenState();
}

class _PayoutTrackerScreenState extends State<PayoutTrackerScreen> {
  bool _isPickingWinner = false;
  bool _isCreatingSeason = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoolProvider>().loadPool(widget.poolId);
    });
  }

  bool _isPoolAdmin(Map<String, dynamic> pool, String? authAddress,
      String? connectedAddress) {
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

  String _truncateAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }

  Future<void> _pickWinnerAuto(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    if (_isPickingWinner) return;
    final caller = context.read<AuthProvider>().walletAddress ?? wallet.walletAddress;
    if (caller == null || caller.isEmpty) {
      AppSnackbarService.instance.warning(
        message: 'Connect wallet as pool admin to pick winner.',
        dedupeKey: 'payout_pick_winner_no_caller',
      );
      return;
    }

    setState(() => _isPickingWinner = true);
    final result = await pools.pickWinnerForActiveRound(widget.poolId);
    if (!mounted) return;
    setState(() => _isPickingWinner = false);

    if (result == null) {
      AppSnackbarService.instance.error(
        message: pools.errorMessage ?? 'Failed to pick winner.',
        dedupeKey: 'payout_pick_winner_failed',
      );
      return;
    }

    final winner = result['winner']?['wallet']?.toString() ?? '';
    AppSnackbarService.instance.success(
      message: winner.isNotEmpty
        ? 'Winner picked: ${_truncateAddress(winner)}.'
          : 'Winner picked successfully.',
      dedupeKey: 'payout_pick_winner_success',
    );

    final authWallet = context.read<AuthProvider>().walletAddress;
    if (authWallet != null) {
      await context.read<WalletProvider>().refreshAfterTx(authWallet);
    }
    await pools.loadPool(widget.poolId);
  }

  Future<void> _showConfigureNextSeasonDialog(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final season = pool['season'] as Map<String, dynamic>?;
    final contributionController = TextEditingController(
      text: (season?['contributionAmount'] ?? pool['contributionAmount'] ?? '').toString(),
    );
    final tokenController = TextEditingController(
      text: (season?['token'] ?? pool['token'] ?? '').toString(),
    );
    final payoutSplitController = TextEditingController(
      text: (season?['payoutSplitPct'] ?? 20).toString(),
    );
    final cadenceController = TextEditingController(
      text: (season?['cadence'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configure Next Season'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: contributionController,
                      decoration: const InputDecoration(
                        labelText: 'Contribution Amount (wei)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Token Address',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: payoutSplitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Payout Split %',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cadenceController,
                      decoration: const InputDecoration(
                        labelText: 'Cadence (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isCreatingSeason
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isCreatingSeason
                      ? null
                      : () async {
                          final caller = context.read<AuthProvider>().walletAddress ?? wallet.walletAddress;
                          if (caller == null || caller.isEmpty) {
                            AppSnackbarService.instance.warning(
                              message: 'Connect wallet as pool admin to configure next season.',
                              dedupeKey: 'payout_next_season_no_caller',
                            );
                            return;
                          }

                          setState(() => _isCreatingSeason = true);
                          setDialogState(() {});
                          final result = await pools.createNextSeason(
                            poolId: widget.poolId,
                            caller: caller,
                            contributionAmount: contributionController.text.trim(),
                            token: tokenController.text.trim(),
                            payoutSplitPct:
                                int.tryParse(payoutSplitController.text.trim()),
                            cadence: cadenceController.text.trim().isEmpty
                                ? null
                                : cadenceController.text.trim(),
                          );
                          if (!mounted) return;
                          setState(() => _isCreatingSeason = false);

                          if (result == null) {
                            AppSnackbarService.instance.error(
                              message: pools.errorMessage ??
                                  'Failed to create next season.',
                              dedupeKey: 'payout_next_season_failed',
                            );
                            setDialogState(() {});
                            return;
                          }

                          if (context.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          AppSnackbarService.instance.success(
                            message: 'Next season configured. Round 1 is open.',
                            dedupeKey: 'payout_next_season_success',
                          );
                          await pools.loadPool(widget.poolId);
                        },
                  child: _isCreatingSeason
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Season'),
                ),
              ],
            );
          },
        );
      },
    );

    contributionController.dispose();
    tokenController.dispose();
    payoutSplitController.dispose();
    cadenceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletService>();
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
            final season = pool['season'] as Map<String, dynamic>?;
            final seasonComplete = (pool['seasonComplete'] == true) ||
              ((season?['status']?.toString() ?? '').toLowerCase() ==
                'completed');
            final roundClosedWinnerPending =
              status.toLowerCase() == 'round-closed' && !seasonComplete;
            final isPoolAdmin =
              _isPoolAdmin(pool, auth.walletAddress, wallet.walletAddress);
            final canPickWinner = isPoolAdmin &&
              wallet.isConnected &&
              roundClosedWinnerPending &&
              !_isPickingWinner &&
              !poolProvider.isLoading;

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

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Winner Action',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canPickWinner
                                ? () =>
                                    _pickWinnerAuto(poolProvider, wallet, pool)
                                : null,
                            icon: _isPickingWinner
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.emoji_events_outlined),
                            label: Text(_isPickingWinner
                                ? 'Picking Winner...'
                                : 'Pick Winner (Auto)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          seasonComplete
                              ? 'Season complete. Configure next season to continue.'
                              : roundClosedWinnerPending
                                  ? 'Winner can now be picked for the active closed round.'
                                  : 'Close the round first from Pool Status.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (seasonComplete) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Season Complete',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Completed ${season?['completedRounds'] ?? 0} / ${season?['totalRounds'] ?? 0} rounds.',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: (isPoolAdmin && wallet.isConnected)
                                  ? () => _showConfigureNextSeasonDialog(
                                      poolProvider,
                                      wallet,
                                      pool,
                                    )
                                  : null,
                              child: const Text('Configure Next Season'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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
