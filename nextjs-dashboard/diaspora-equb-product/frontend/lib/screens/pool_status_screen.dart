import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/collateral_provider.dart';
import '../providers/network_provider.dart';
import '../providers/pool_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
import '../services/wallet_service.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../widgets/desktop_layout.dart';

class PoolStatusScreen extends StatefulWidget {
  final String poolId;
  final bool embeddedDesktop;

  const PoolStatusScreen({
    super.key,
    required this.poolId,
    this.embeddedDesktop = false,
  });

  @override
  State<PoolStatusScreen> createState() => _PoolStatusScreenState();
}

class _PoolStatusScreenState extends State<PoolStatusScreen> {
  bool _isContributing = false;
  bool _isJoining = false;
  bool _isBindingIdentity = false;
  bool _isClosingRound = false;
  final GlobalKey _membersSectionKey = GlobalKey();

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

    if (mounted) {
      final auth = context.read<AuthProvider>();
      final wallet = context.read<WalletProvider>();
      final network = context.read<NetworkProvider>();
      if (auth.walletAddress != null) {
        unawaited(wallet.loadBalance(auth.walletAddress!,
            token: network.nativeSymbol));
      }
    }
  }

  Future<void> _scrollToMembersSection() async {
    final sectionContext = _membersSectionKey.currentContext;
    if (sectionContext == null) return;

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openPayoutStream() {
    context.push('/payouts/${widget.poolId}');
  }

  String _tokenSymbolFor(BuildContext ctx) {
    return ctx.read<NetworkProvider>().nativeSymbol;
  }

  String _shortTx(String txHash, {int length = 12}) {
    if (txHash.length <= length) return txHash;
    return txHash.substring(0, length);
  }

  String _formatContributionDisplay(String raw) {
    final sym = _tokenSymbolFor(context);
    final wei = BigInt.tryParse(raw);
    if (wei != null && !raw.contains('.') && wei > BigInt.from(1e15)) {
      final eth = wei / BigInt.from(10).pow(18);
      final remainder = wei % BigInt.from(10).pow(18);
      final decimals = (remainder / BigInt.from(10).pow(14)).toInt();
      if (decimals == 0) return '${eth.toString()} $sym';
      return '${eth.toString()}.${decimals.toString().padLeft(4, '0').replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    final n = double.tryParse(raw);
    if (n == null) return '$raw $sym';
    if (n == n.truncateToDouble()) return '${n.toInt()} $sym';
    if (n < 0.01) {
      return '${n.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    if (n < 1) {
      return '${n.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    return '${n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} $sym';
  }

  bool _isMemberOfPool(Map<String, dynamic> pool, String? walletAddress) {
    if (walletAddress == null || walletAddress.trim().isEmpty) return false;
    final members = (pool['members'] as List?) ?? const [];
    final me = walletAddress.toLowerCase().trim();
    for (final member in members) {
      String address;
      if (member is Map) {
        address =
            (member['walletAddress'] ?? '').toString().toLowerCase().trim();
      } else {
        address = member.toString().toLowerCase().trim();
      }
      if (address == me) return true;
    }
    return false;
  }

  bool _isMemberOfPoolAny(
      Map<String, dynamic> pool, String? authAddr, String? walletAddr) {
    return _isMemberOfPool(pool, authAddr) || _isMemberOfPool(pool, walletAddr);
  }

  /// True if the user is the pool admin: only the wallet that signed pool creation (createdBy).
  /// Treasury does not define admin; only the creation signer does.
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

  Future<void> _closeRoundOnly(
    PoolProvider pools,
    Map<String, dynamic> pool,
  ) async {
    final isSeasonComplete = (pool['seasonComplete'] == true) ||
        ((pool['season']?['status']?.toString() ?? '') == 'completed');
    if (isSeasonComplete) {
      AppSnackbarService.instance.warning(
        message: 'Season is complete. Configure next season to continue.',
        dedupeKey: 'pool_status_season_complete_close_block',
      );
      return;
    }

    final roundStatus = pool['currentRoundStatus']?.toString() ??
        (pool['activeRound']?['status']?.toString() ?? 'open');
    if (roundStatus != 'open') {
      AppSnackbarService.instance.warning(
        message: 'Active round is not open.',
        dedupeKey: 'pool_status_round_not_open',
      );
      return;
    }

    setState(() => _isClosingRound = true);
    final result = await pools.closeActiveRound(widget.poolId);
    if (!mounted) return;
    setState(() => _isClosingRound = false);
    if (result != null) {
      context.read<NotificationProvider>().triggerFastSync();
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context
            .read<WalletProvider>()
            .refreshAfterTx(auth.walletAddress!);
      }
      await pools.loadPool(widget.poolId);

      if (!mounted) return;
      AppSnackbarService.instance.success(
        message:
            'Round closed successfully. Winner picking is now available in Payout Stream.',
        dedupeKey: 'pool_status_close_round_success',
      );
    } else {
      AppSnackbarService.instance.error(
        message: pools.errorMessage ?? 'Close round failed or was rejected',
        dedupeKey: 'pool_status_close_round_failed',
      );
    }
  }

  Future<void> _contributeOnChain(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    final contributionAmount = pool['contributionAmount'] ?? '0';

    debugPrint(
        '[Contribute] START: onChainPoolId=$onChainPoolId, amount=$contributionAmount, walletConnected=${wallet.isConnected}, walletAddr=${wallet.walletAddress}');

    if (onChainPoolId == null) {
      AppSnackbarService.instance.warning(
        message:
            'This equb has no on-chain ID yet — it must be created on-chain first.',
        dedupeKey: 'pool_status_missing_onchain_id_contribute',
      );
      return;
    }

    if (!wallet.isConnected) {
      debugPrint('[Contribute] Wallet not connected, calling connect()...');
      AppSnackbarService.instance.info(
        message: 'Connecting to MetaMask...',
        dedupeKey: 'pool_status_connecting_wallet',
        duration: const Duration(seconds: 2),
      );
      final addr = await wallet.connect();
      if (!mounted) return;
      debugPrint(
          '[Contribute] Connect result: addr=$addr, error=${wallet.errorMessage}');
      if (addr == null) {
        AppSnackbarService.instance.error(
          message: wallet.errorMessage ??
              'MetaMask connection failed. Make sure MetaMask is installed and unlocked.',
          dedupeKey: 'pool_status_wallet_not_connected',
          duration: const Duration(seconds: 5),
        );
        return;
      }
    }

    setState(() => _isContributing = true);

    final poolSymbol = _tokenSymbolFor(context);

    AppSnackbarService.instance.info(
      message: 'Building $poolSymbol contribution TX — confirm in wallet...',
      dedupeKey: 'pool_status_contribute_pending',
      duration: const Duration(seconds: 4),
    );

    String? txHash;

    try {
      debugPrint(
          '[Contribute] Native $poolSymbol flow: buildAndSignContribute(poolId=$onChainPoolId, amount=$contributionAmount)');
      txHash = await pools.buildAndSignContribute(
        onChainPoolId as int,
        contributionAmount.toString(),
        poolId: widget.poolId,
      );
    } catch (e) {
      debugPrint('[Contribute] EXCEPTION: $e');
      if (!mounted) return;
      setState(() => _isContributing = false);
      AppSnackbarService.instance.error(
        message: 'Contribution error: $e',
        dedupeKey: 'pool_status_contribute_exception',
        duration: const Duration(seconds: 6),
      );
      return;
    }

    debugPrint(
        '[Contribute] Result: txHash=$txHash, error=${pools.errorMessage}');

    if (!mounted) return;
    setState(() => _isContributing = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context.read<WalletProvider>().refreshAfterTx(
              auth.walletAddress!,
            );
      }
      if (!mounted) return;
      await _loadPoolData();
      if (!mounted) return;

      AppSnackbarService.instance.success(
        message: 'Contribution confirmed! TX: ${txHash.substring(0, 16)}...',
        dedupeKey: 'pool_status_contribute_success_$txHash',
        duration: const Duration(seconds: 4),
        actionLabel: 'View',
        onAction: () {
          debugPrint('${AppConfig.explorerUrl}/tx/$txHash');
        },
      );
    } else {
      final err = pools.errorMessage ??
          wallet.errorMessage ??
          'Transaction was rejected or failed';
      debugPrint('[Contribute] FAILED: $err');
      AppSnackbarService.instance.error(
        message:
            '$err\n\nMake sure you are a member of this equb, have enough $poolSymbol balance, and approve the transaction in MetaMask.',
        dedupeKey: 'pool_status_contribute_failed',
        duration: const Duration(seconds: 8),
      );
    }
  }

  Future<void> _joinPoolOnChain(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    debugPrint(
        '[Join] START: onChainPoolId=$onChainPoolId, walletConnected=${wallet.isConnected}');

    if (onChainPoolId == null) {
      AppSnackbarService.instance.warning(
        message:
            'This equb has no on-chain ID yet — it must be created on-chain first.',
        dedupeKey: 'pool_status_missing_onchain_id_join',
      );
      return;
    }

    if (!wallet.isConnected) {
      debugPrint('[Join] Wallet not connected, calling connect()...');
      final addr = await wallet.connect();
      if (!mounted) return;
      debugPrint(
          '[Join] Connect result: addr=$addr, error=${wallet.errorMessage}');
      if (addr == null) {
        AppSnackbarService.instance.error(
          message: wallet.errorMessage ??
              'MetaMask connection failed. Make sure MetaMask is installed and unlocked.',
          dedupeKey: 'pool_status_wallet_not_connected_join',
          duration: const Duration(seconds: 5),
        );
        return;
      }
    }

    setState(() => _isJoining = true);
    AppSnackbarService.instance.info(
      message: 'Joining equb — confirm in MetaMask...',
      dedupeKey: 'pool_status_join_pending',
      duration: const Duration(seconds: 4),
    );

    final caller = wallet.walletAddress;
    final txHash = await pools.buildAndSignJoinPool(
      onChainPoolId as int,
      caller: caller,
    );
    if (!mounted) return;
    setState(() => _isJoining = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      final auth = context.read<AuthProvider>();
      if (auth.walletAddress != null) {
        await context
            .read<WalletProvider>()
            .refreshAfterTx(auth.walletAddress!);
      }
      await pools.loadPool(widget.poolId);
      if (!mounted) return;

      AppSnackbarService.instance.success(
        message:
            'Joined equb successfully! TX: ${_shortTx(txHash, length: 16)}...',
        dedupeKey: 'pool_status_join_success_$txHash',
        duration: const Duration(seconds: 4),
        actionLabel: 'View',
        onAction: () => debugPrint('${AppConfig.explorerUrl}/tx/$txHash'),
      );
    } else {
      final err = pools.errorMessage ?? 'Join failed or rejected';
      final isIdentityNotBound =
          err.toLowerCase().contains('identity is not bound on-chain');
      AppSnackbarService.instance.error(
        message:
            '$err\nTip: Make sure your wallet is identity-verified and the equb still has open member slots.',
        dedupeKey: 'pool_status_join_failed',
        duration: const Duration(seconds: 6),
        actionLabel: isIdentityNotBound ? 'Bind Now' : null,
        onAction: isIdentityNotBound
            ? () {
                final auth = context.read<AuthProvider>();
                _bindIdentityOnChain(auth);
              }
            : null,
      );
    }
  }

  Future<void> _bindIdentityOnChain(AuthProvider auth) async {
    if (_isBindingIdentity) return;

    setState(() => _isBindingIdentity = true);
    AppSnackbarService.instance.info(
      message: 'Binding identity on-chain — confirm in wallet...',
      dedupeKey: 'pool_status_bind_identity_pending',
      duration: const Duration(seconds: 3),
    );

    final txHash = await auth.bindIdentityOnChain();
    if (!mounted) return;
    setState(() => _isBindingIdentity = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      if (auth.walletAddress != null) {
        await context
            .read<WalletProvider>()
            .refreshAfterTx(auth.walletAddress!);
      }
      if (!mounted) return;
      AppSnackbarService.instance.success(
        message:
            'Identity bound on-chain. TX: ${_shortTx(txHash, length: 16)}... You can now join the equb.',
        dedupeKey: 'pool_status_bind_identity_success_$txHash',
        duration: const Duration(seconds: 5),
        actionLabel: 'View',
        onAction: () => debugPrint('${AppConfig.explorerUrl}/tx/$txHash'),
      );
    } else {
      AppSnackbarService.instance.error(
        message:
            auth.errorMessage ?? 'Identity binding failed or was rejected.',
        dedupeKey: 'pool_status_bind_identity_failed',
        duration: const Duration(seconds: 6),
      );
    }
  }

  Widget _buildAdaptiveActionButton(
    BuildContext context, {
    required Map<String, dynamic> pool,
    required bool isMember,
    required bool hasOpenSlots,
    required PoolProvider pools,
    required WalletService wallet,
    required AuthProvider auth,
  }) {
    final bool isBusy =
        _isBindingIdentity || _isJoining || _isContributing || pools.isLoading;

    if (isMember) {
      final round = pool['currentRound'] ?? 1;
      final poolSym = _tokenSymbolFor(context);
      final label = 'Contribute $poolSym (Round $round)';
      const hint =
          'Your wallet (MetaMask) will pop up to sign this transaction.';

      // Collateral gate: check if user has locked enough collateral for this pool
      final collateral = context.watch<CollateralProvider>();
      final contributionRaw = pool['contributionAmount']?.toString() ?? '0';
      final wei = BigInt.tryParse(contributionRaw) ?? BigInt.zero;
      final div = BigInt.from(10).pow(18);
      final requiredCollateral =
          (wei ~/ div).toDouble() + (wei % div).toDouble() / 1e18;
      final poolLocked = collateral.lockedForPool(widget.poolId);
      final hasEnoughCollateral =
          poolLocked >= requiredCollateral && requiredCollateral > 0;

      if (!hasEnoughCollateral && requiredCollateral > 0) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : () => context.push('/collateral'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentYellow,
                  foregroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.lock_outline, size: 20),
                label: const Text(
                  'Lock Collateral First',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lock collateral equal to one round\'s contribution before contributing.',
              style: TextStyle(
                  color: AppTheme.textTertiaryColor(context), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed:
                  isBusy ? null : () => _contributeOnChain(pools, wallet, pool),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor(context),
                foregroundColor: AppTheme.buttonTextColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              icon: _isContributing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.buttonTextColor(context),
                      ),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined, size: 20),
              label: Text(
                _isContributing ? 'Contributing...' : label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: TextStyle(
              color: AppTheme.textTertiaryColor(context),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (!hasOpenSlots) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.block, size: 20),
              label: const Text(
                'Equb Full',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This equb is full. No additional members can join.',
            style: TextStyle(
              color: AppTheme.textTertiaryColor(context),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // State: not a member, has open slots — show the next required step
    // Try join first; if it fails the user can tap again to bind identity
    if (_isBindingIdentity) {
      return _buildSingleActionBtn(
        context,
        label: 'Binding Identity...',
        icon: null,
        loading: true,
        onPressed: null,
        color: AppTheme.primaryColor,
        hint:
            'Confirm the transaction in your wallet to bind your identity on-chain.',
      );
    }

    if (_isJoining) {
      return _buildSingleActionBtn(
        context,
        label: 'Joining Equb...',
        icon: null,
        loading: true,
        onPressed: null,
        color: AppTheme.primaryColor,
        hint: 'Confirm the transaction in your wallet to join this equb.',
      );
    }

    return _buildSingleActionBtn(
      context,
      label: 'Join Equb',
      icon: Icons.group_add_outlined,
      loading: false,
      onPressed: isBusy ? null : () => _smartJoin(pools, wallet, pool, auth),
      color: AppTheme.primaryColor,
      hint: 'Your identity will be bound on-chain automatically if needed.',
    );
  }

  Widget _buildSingleActionBtn(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required bool loading,
    required VoidCallback? onPressed,
    required Color color,
    required String hint,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            icon: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 20),
            label: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hint,
          style: TextStyle(
            color: AppTheme.textTertiaryColor(context),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _smartJoin(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
    AuthProvider auth,
  ) async {
    final onChainPoolId = pool['onChainPoolId'];
    if (onChainPoolId == null) return;

    setState(() => _isJoining = true);

    AppSnackbarService.instance.info(
      message: 'Joining equb — confirm in wallet...',
      dedupeKey: 'pool_status_smart_join_pending',
      duration: const Duration(seconds: 3),
    );

    final caller = wallet.walletAddress;
    final joinTx = await pools.buildAndSignJoinPool(
      onChainPoolId as int,
      caller: caller,
    );

    if (!mounted) return;

    if (joinTx != null) {
      context.read<NotificationProvider>().triggerFastSync();
      if (auth.walletAddress != null) {
        await context
            .read<WalletProvider>()
            .refreshAfterTx(auth.walletAddress!);
      }
      if (!mounted) return;
      setState(() => _isJoining = false);
      await _loadPoolData();
      if (!mounted) return;
      AppSnackbarService.instance.success(
        message: 'Joined equb! You can now contribute.',
        dedupeKey: 'pool_status_smart_join_success',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Join failed — likely identity not bound. Try binding first.
    final joinError = pools.errorMessage ?? '';
    setState(() {
      _isJoining = false;
      _isBindingIdentity = true;
    });

    final identityNeeded = joinError.toLowerCase().contains('identity') ||
        joinError.toLowerCase().contains('not registered') ||
        joinError.toLowerCase().contains('revert') ||
        joinError.isNotEmpty;

    if (identityNeeded) {
      AppSnackbarService.instance.info(
        message: 'Binding identity on-chain first — confirm in wallet...',
        dedupeKey: 'pool_status_smart_bind_pending',
        duration: const Duration(seconds: 3),
      );

      final txHash = await auth.bindIdentityOnChain();
      if (!mounted) return;
      setState(() => _isBindingIdentity = false);

      if (txHash != null) {
        context.read<NotificationProvider>().triggerFastSync();
        if (auth.walletAddress != null) {
          await context
              .read<WalletProvider>()
              .refreshAfterTx(auth.walletAddress!);
        }
        if (!mounted) return;
        AppSnackbarService.instance.success(
          message: 'Identity bound! Now joining equb...',
          dedupeKey: 'pool_status_smart_bind_success',
          duration: const Duration(seconds: 3),
        );

        // Retry join after binding
        await _joinPoolOnChain(pools, wallet, pool);
      } else {
        AppSnackbarService.instance.error(
          message:
              auth.errorMessage ?? 'Identity binding failed. Please try again.',
          dedupeKey: 'pool_status_smart_bind_failed',
          duration: const Duration(seconds: 5),
        );
      }
    } else {
      setState(() => _isBindingIdentity = false);
      AppSnackbarService.instance.error(
        message: joinError.isNotEmpty ? joinError : 'Failed to join equb.',
        dedupeKey: 'pool_status_smart_join_failed',
        duration: const Duration(seconds: 5),
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
    final embeddedDesktop = widget.embeddedDesktop && AppTheme.isDesktop(context);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: embeddedDesktop
            ? null
            : AppBar(
                title: Text(pool?['name']?.toString() ?? 'Equb Status'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    tooltip: 'Refresh',
                    onPressed: () async => _loadPoolData(),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 22),
                    onSelected: (v) {
                      if (v == 'payouts') _openPayoutStream();
                      if (v == 'governance') {
                        context.push('/equb-governance/${widget.poolId}');
                      }
                      if (v == 'rules') {
                        context.push('/equb-rules/${widget.poolId}');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'payouts', child: Text('Payout Stream')),
                      PopupMenuItem(value: 'governance', child: Text('Governance')),
                      PopupMenuItem(value: 'rules', child: Text('Rules')),
                    ],
                  ),
                ],
              ),
        bottomNavigationBar: pool != null && auth.walletAddress != null
            ? _buildStickyBottomBar(context, pool, pools, wallet, auth)
            : null,
        body: pool == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPoolData,
                child: Builder(
                  builder: (context) {
                    final isPoolAdmin = _isPoolAdmin(
                        pool, auth.walletAddress, wallet.walletAddress);
                    final members = (pool['members'] as List?) ?? const [];
                    final memberCount = members.length;
                    final maxMembers =
                        int.tryParse('${pool['maxMembers'] ?? 0}') ?? 0;
                    final season = pool['season'] as Map<String, dynamic>?;
                    final seasonComplete = (pool['seasonComplete'] == true) ||
                        ((season?['status']?.toString() ?? '').toLowerCase() ==
                            'completed');
                    final currentRoundStatus =
                        (pool['currentRoundStatus']?.toString() ??
                                pool['activeRound']?['status']?.toString() ??
                                '')
                            .toLowerCase();
                    final canCloseRound = isPoolAdmin &&
                        pool['onChainPoolId'] != null &&
                        wallet.isConnected &&
                        !seasonComplete;
                    final currentRound =
                        (pool['currentRound'] as num?)?.toInt() ?? 1;
                    final progress = maxMembers > 0
                        ? (currentRound / maxMembers).clamp(0.0, 1.0)
                        : 0.0;

                    final mobileBody = ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        _buildHeroPayoutCard(
                            context,
                            pool,
                            members,
                            currentRound,
                            maxMembers,
                            progress,
                            currentRoundStatus),
                        const SizedBox(height: 20),
                        _buildPayoutScheduleSection(
                            context, pool, members, currentRound, auth, wallet),
                        const SizedBox(height: 20),
                        if (auth.walletAddress != null &&
                            wallet.isConnected) ...[
                          _buildBalancePreviewCard(
                              context, walletProvider, pool),
                          const SizedBox(height: 20),
                        ],
                        if (pool['onChainPoolId'] != null || isPoolAdmin) ...[
                          _buildAdminCard(context, pools, pool, canCloseRound,
                              seasonComplete, wallet, isPoolAdmin),
                          const SizedBox(height: 20),
                        ],
                        _buildMembersSection(context, members, memberCount,
                            maxMembers, auth, wallet),
                        const SizedBox(height: 16),
                        if (pools.lastTxHash != null)
                          _buildLastTxCard(context, pools.lastTxHash!),
                      ],
                    );

                    final desktopBody = SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      child: DesktopContent(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DesktopSectionTitle(
                              title: pool['name']?.toString() ?? 'Equb Status',
                              subtitle: 'Round status, members, payouts, and management all stay inside the desktop workspace.',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _loadPoolData,
                                    icon: const Icon(Icons.refresh_rounded, size: 22),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz_rounded, size: 22),
                                    onSelected: (v) {
                                      if (v == 'payouts') _openPayoutStream();
                                      if (v == 'governance') {
                                        context.push('/equb-governance/${widget.poolId}');
                                      }
                                      if (v == 'rules') {
                                        context.push('/equb-rules/${widget.poolId}');
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'payouts', child: Text('Payout Stream')),
                                      PopupMenuItem(value: 'governance', child: Text('Governance')),
                                      PopupMenuItem(value: 'rules', child: Text('Rules')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.desktopSectionGap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    children: [
                                      _buildHeroPayoutCard(
                                          context,
                                          pool,
                                          members,
                                          currentRound,
                                          maxMembers,
                                          progress,
                                          currentRoundStatus),
                                      const SizedBox(
                                          height: AppTheme.desktopSectionGap),
                                      _buildPayoutScheduleSection(context, pool,
                                          members, currentRound, auth, wallet),
                                      if (pools.lastTxHash != null) ...[
                                        const SizedBox(
                                            height: AppTheme.desktopSectionGap),
                                        _buildLastTxCard(
                                            context, pools.lastTxHash!),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppTheme.desktopPanelGap),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      if (isPoolAdmin) ...[
                                        _buildDesktopManagementCard(context),
                                        const SizedBox(
                                            height: AppTheme.desktopSectionGap),
                                      ],
                                      if (auth.walletAddress != null &&
                                          wallet.isConnected) ...[
                                        _buildBalancePreviewCard(
                                            context, walletProvider, pool),
                                        const SizedBox(
                                            height: AppTheme.desktopSectionGap),
                                      ],
                                      if (pool['onChainPoolId'] != null ||
                                          isPoolAdmin) ...[
                                        _buildAdminCard(
                                            context,
                                            pools,
                                            pool,
                                            canCloseRound,
                                            seasonComplete,
                                            wallet,
                                            isPoolAdmin),
                                        const SizedBox(
                                            height: AppTheme.desktopSectionGap),
                                      ],
                                      KeyedSubtree(
                                        key: _membersSectionKey,
                                        child: _buildMembersSection(
                                            context,
                                            members,
                                            memberCount,
                                            maxMembers,
                                            auth,
                                            wallet),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    return AppTheme.isDesktop(context)
                        ? desktopBody
                        : mobileBody;
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildHeroPayoutCard(
      BuildContext context,
      Map<String, dynamic> pool,
      List members,
      int currentRound,
      int maxMembers,
      double progress,
      String roundStatus) {
    final contribution = _formatContributionDisplay(
        pool['contributionAmount']?.toString() ?? '0');
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEXT PAYOUT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppTheme.textTertiaryColor(context))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppTheme.positive),
                    const SizedBox(width: 5),
                    Text('Round $currentRound',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.positive)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contribution,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryColor(context),
                letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSmallAvatarStack(context, members),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Turn',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context))),
                    Text('Cycle $currentRound of $maxMembers',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiaryColor(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  AppTheme.textHintColor(context).withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatarStack(BuildContext context, List members) {
    final count = members.length;
    final show = count > 3 ? 3 : count;
    final colors = [
      AppTheme.accentYellow,
      AppTheme.positive,
      AppTheme.secondaryColor
    ];
    return SizedBox(
      width: show * 18.0 + (count > 3 ? 18 : 0) + 6,
      height: 28,
      child: Stack(
        children: [
          for (int i = 0; i < show; i++)
            Positioned(
              left: i * 16.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i % colors.length].withValues(alpha: 0.25),
                  border:
                      Border.all(color: AppTheme.cardColor(context), width: 2),
                ),
                child: Icon(Icons.person,
                    size: 14, color: colors[i % colors.length]),
              ),
            ),
          if (count > 3)
            Positioned(
              left: show * 16.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.textHintColor(context).withValues(alpha: 0.3),
                  border:
                      Border.all(color: AppTheme.cardColor(context), width: 2),
                ),
                child: Center(
                    child: Text('+${count - 3}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryColor(context)))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPayoutScheduleSection(
      BuildContext context,
      Map<String, dynamic> pool,
      List members,
      int currentRound,
      AuthProvider auth,
      WalletService wallet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Payout Schedule',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => context.push('/payouts/${widget.poolId}'),
              child: const Text('View Full',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: Column(
            children: [
              for (int i = 0; i < members.length && i < 4; i++)
                _buildTimelineEntry(
                    context, i, members, currentRound, auth, wallet),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEntry(BuildContext context, int index, List members,
      int currentRound, AuthProvider auth, WalletService wallet) {
    final member = members[index];
    final address =
        (member is Map ? member['walletAddress'] ?? '' : member.toString())
            .toString();
    final addrLower = address.toLowerCase();
    final isCurrentUser =
        addrLower == (auth.walletAddress ?? '').toLowerCase() ||
            addrLower == (wallet.walletAddress ?? '').toLowerCase();
    final roundNum = index + 1;
    final isPast = roundNum < currentRound;
    final isCurrent = roundNum == currentRound;
    final isLast = index == members.length - 1 || index == 3;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPast
                        ? AppTheme.positive
                        : isCurrent
                            ? AppTheme.primaryColor
                            : AppTheme.textHintColor(context),
                    border: isCurrent
                        ? Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            width: 3)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2,
                        color: AppTheme.textHintColor(context)
                            .withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrent && isCurrentUser
                              ? '${_truncateAddress(address)} (You)'
                              : _truncateAddress(address),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent
                                ? AppTheme.textPrimaryColor(context)
                                : AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        if (isCurrent && isCurrentUser)
                          const Text('Receiving payout',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.positive)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPast
                          ? AppTheme.positive.withValues(alpha: 0.1)
                          : isCurrent
                              ? AppTheme.accentYellow.withValues(alpha: 0.15)
                              : AppTheme.textHintColor(context)
                                  .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPast
                          ? 'Paid'
                          : isCurrent
                              ? 'Next'
                              : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPast
                            ? AppTheme.positive
                            : isCurrent
                                ? AppTheme.accentYellow
                                : AppTheme.textTertiaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(
      BuildContext context,
      PoolProvider pools,
      Map<String, dynamic> pool,
      bool canCloseRound,
      bool seasonComplete,
      WalletService wallet,
      bool isPoolAdmin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    size: 20, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Text('Danna (Admin)',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canCloseRound && !_isClosingRound && !pools.isLoading
                  ? () => _closeRoundOnly(pools, pool)
                  : null,
              icon: _isClosingRound
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.flag_outlined, size: 20),
              label: Text(_isClosingRound ? 'Closing round...' : 'Close round'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            seasonComplete
                ? 'Season is complete. Configure the next season to continue.'
                : canCloseRound
                    ? 'Close only the active round. Winner selection is handled in Payout Stream.'
                    : 'Only the creator wallet can close the active round.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textTertiaryColor(context)),
          ),
          if (!canCloseRound) ...[
            const SizedBox(height: 8),
            if (!wallet.isConnected)
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppTheme.warningColor),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Connect your wallet to enable close round.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiaryColor(context)))),
              ]),
            if (wallet.isConnected && !isPoolAdmin)
              Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppTheme.warningColor),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                        'Only the wallet that signed equb creation can close rounds.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiaryColor(context)))),
              ]),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopManagementCard(BuildContext context) {
    return DesktopCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_customize_outlined,
                    size: 20, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Creator Management',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Manage this Equb from the desktop sidebar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildManagementActionTile(
            context,
            icon: Icons.groups_rounded,
            title: 'Members',
            subtitle: 'Jump to the current member roster',
            onTap: _scrollToMembersSection,
          ),
          const SizedBox(height: 10),
          _buildManagementActionTile(
            context,
            icon: Icons.payments_outlined,
            title: 'Payouts',
            subtitle: 'Open the payout stream for this Equb',
            onTap: _openPayoutStream,
          ),
          const SizedBox(height: 10),
          _buildManagementActionTile(
            context,
            icon: Icons.emoji_events_outlined,
            title: 'Winner Selection',
            subtitle: 'Continue in payout stream to pick a winner',
            onTap: _openPayoutStream,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: AppTheme.borderFor(context, opacity: 0.04),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    AppTheme.textPrimaryColor(context).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppTheme.textTertiaryColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(
      BuildContext context,
      List members,
      int memberCount,
      int maxMembers,
      AuthProvider auth,
      WalletService wallet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Members ($memberCount/$maxMembers)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: Column(
            children: [
              for (int i = 0; i < members.length; i++) ...[
                _buildMemberRow(context, members[i], i, auth, wallet),
                if (i < members.length - 1)
                  Divider(
                      height: 1,
                      indent: 60,
                      color: AppTheme.textHintColor(context)
                          .withValues(alpha: 0.3)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(BuildContext context, dynamic member, int index,
      AuthProvider auth, WalletService wallet) {
    final address =
        (member is Map ? member['walletAddress'] ?? '' : member.toString())
            .toString();
    final addrLower = address.toLowerCase();
    final isCurrentUser =
        addrLower == (auth.walletAddress ?? '').toLowerCase() ||
            addrLower == (wallet.walletAddress ?? '').toLowerCase();
    final colors = [
      AppTheme.accentYellow,
      AppTheme.positive,
      AppTheme.secondaryColor,
      AppTheme.primaryColor
    ];
    final c = colors[index % colors.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? AppTheme.primaryColor
                    : c.withValues(alpha: 0.2)),
            child: Icon(Icons.person,
                size: 18, color: isCurrentUser ? Colors.white : c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_truncateAddress(address),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimaryColor(context))),
                Text(isCurrentUser ? 'You' : 'Member',
                    style: TextStyle(
                        fontSize: 12,
                        color: isCurrentUser
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiaryColor(context))),
              ],
            ),
          ),
          if (isCurrentUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('You',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, Map<String, dynamic> pool,
      PoolProvider pools, WalletService wallet, AuthProvider auth) {
    final isMember =
        _isMemberOfPoolAny(pool, auth.walletAddress, wallet.walletAddress);
    final memberCount = ((pool['members'] as List?) ?? []).length;
    final maxMembers = int.tryParse('${pool['maxMembers'] ?? 0}') ?? 0;
    final hasOpenSlots = maxMembers == 0 || memberCount < maxMembers;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: _buildAdaptiveActionButton(
        context,
        pool: pool,
        isMember: isMember,
        hasOpenSlots: hasOpenSlots,
        pools: pools,
        wallet: wallet,
        auth: auth,
      ),
    );
  }

  Widget _buildLastTxCard(BuildContext context, String txHash) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.successColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Transaction',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context))),
                const SizedBox(height: 2),
                Text(txHash,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancePreviewCard(BuildContext context,
      WalletProvider walletProvider, Map<String, dynamic> pool) {
    final contributionRaw = pool['contributionAmount']?.toString() ?? '0';
    final symbol = _tokenSymbolFor(context);
    final bal = double.tryParse(walletProvider.balanceOf(symbol)) ?? 0;
    final wei = BigInt.tryParse(contributionRaw) ?? BigInt.zero;
    final div = BigInt.from(10).pow(18);
    final contributionNum =
        (wei ~/ div).toDouble() + (wei % div).toDouble() / 1e18;
    final contributionStr = '-${_formatContributionDisplay(contributionRaw)}';
    const decimals = 6;
    final currentBalance = bal.toStringAsFixed(decimals);
    final afterBalance = (bal - contributionNum).toStringAsFixed(decimals);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 20, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text('Your balance',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor(context))),
          ]),
          const SizedBox(height: 12),
          Text('$currentBalance $symbol',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.5)),
          const SizedBox(height: 14),
          Container(
              height: 1,
              color:
                  AppTheme.textTertiaryColor(context).withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          _balancePreviewRow(context, 'Contribution', contributionStr,
              isNegative: true),
          const SizedBox(height: 6),
          _balancePreviewRow(
              context, 'After contribution', '$afterBalance $symbol',
              isNegative: false),
        ],
      ),
    );
  }

  Widget _balancePreviewRow(BuildContext context, String label, String value,
      {required bool isNegative}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor(context))),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isNegative
                    ? AppTheme.negative
                    : AppTheme.textPrimaryColor(context))),
      ],
    );
  }

  String _truncateAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}
