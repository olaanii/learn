import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/pool_provider.dart';
import '../services/app_snackbar_service.dart';
import '../services/wallet_service.dart';
import '../services/socket_service.dart';
import '../widgets/desktop_layout.dart';
import '../widgets/lottery_draw_modal.dart';

class PayoutTrackerScreen extends StatefulWidget {
  final String poolId;
  final bool embeddedDesktop;

  const PayoutTrackerScreen({
    super.key,
    required this.poolId,
    this.embeddedDesktop = false,
  });

  @override
  State<PayoutTrackerScreen> createState() => _PayoutTrackerScreenState();
}

class _PayoutTrackerScreenState extends State<PayoutTrackerScreen>
    with TickerProviderStateMixin {
  bool _isPickingWinner = false;
  bool _isReleasingPayout = false;
  bool _isCreatingSeason = false;

  // Randomization animation state
  bool _isRandomizing = false;
  String _randomizingDisplay = '';
  List<String> _eligibleMembers = [];
  Timer? _randomizeTimer;
  int _randomizeIndex = 0;
  String? _revealedWinner;

  // Filter
  String _historyFilter = 'All';

  // Socket
  StreamSubscription<EqubSocketEvent>? _socketSub;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoolProvider>().loadPool(widget.poolId);
      _connectSocket();
    });
  }

  void _connectSocket() {
    final socket = SocketService.instance;
    socket.connect();
    socket.subscribeToPool(widget.poolId);

    _socketSub = socket.poolEvents(widget.poolId).listen((event) {
      if (!mounted) return;
      if (event.type == 'winner:randomizing') {
        final members = (event.data['eligibleMembers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        _startRandomizeAnimation(members);
      } else if (event.type == 'winner:picked') {
        final winner = event.data['winnerWallet']?.toString() ?? '';
        _stopRandomizeAnimation(winner);
      }
    });
  }

  void _startRandomizeAnimation(List<String> members) {
    if (members.isEmpty) return;
    setState(() {
      _isRandomizing = true;
      _eligibleMembers = members;
      _revealedWinner = null;
      _randomizeIndex = 0;
    });

    _randomizeTimer?.cancel();
    _randomizeTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _randomizeIndex = (_randomizeIndex + 1) % _eligibleMembers.length;
        _randomizingDisplay = _truncateAddress(_eligibleMembers[_randomizeIndex]);
      });
    });
  }

  void _stopRandomizeAnimation(String winner) {
    _randomizeTimer?.cancel();
    _randomizeTimer = null;

    setState(() {
      _isRandomizing = false;
      _revealedWinner = winner;
      _randomizingDisplay = '';
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _revealedWinner = null);
        context.read<PoolProvider>().loadPool(widget.poolId);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _randomizeTimer?.cancel();
    _socketSub?.cancel();
    SocketService.instance.unsubscribeFromPool(widget.poolId);
    super.dispose();
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

  Future<void> _pickWinnerOnChain(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    if (_isPickingWinner) return;
    final caller =
        context.read<AuthProvider>().walletAddress ?? wallet.walletAddress;
    if (caller == null || caller.isEmpty) {
      AppSnackbarService.instance.warning(
        message: 'Connect wallet to pick winner.',
        dedupeKey: 'payout_pick_winner_no_caller',
      );
      return;
    }

    setState(() => _isPickingWinner = true);

    // Fetch eligible members for the lottery animation
    final eligible = await pools.getEligibleWinners(widget.poolId);
    if (!mounted) return;

    if (eligible.isEmpty) {
      setState(() => _isPickingWinner = false);
      AppSnackbarService.instance.warning(
        message: 'No eligible members for this round.',
        dedupeKey: 'payout_pick_no_eligible',
      );
      return;
    }

    final members = pool['members'] as List? ?? [];
    final contributionAmount =
        double.tryParse(pool['contributionAmount']?.toString() ?? '0') ?? 0;
    final totalPrize = contributionAmount * members.length;

    // Open lottery modal — the draw executes inside the modal
    final winner = await LotteryDrawModal.show(
      context,
      eligibleMembers: eligible,
      onDraw: () async {
        final result = await pools.buildAndSignSelectWinner(
          poolId: widget.poolId,
          total: totalPrize.toStringAsFixed(0),
          upfrontPercent: pool['season']?['payoutSplitPct'] ?? 20,
          totalRounds: pool['maxMembers'] ?? members.length,
          caller: caller,
          onProgress: (msg) {
            if (mounted) {
              AppSnackbarService.instance.info(
                message: msg,
                dedupeKey: 'payout_progress',
              );
            }
          },
        );
        return result?['winner']?.toString();
      },
    );

    if (!mounted) return;
    setState(() => _isPickingWinner = false);

    if (winner != null && winner.isNotEmpty) {
      AppSnackbarService.instance.success(
        message: 'Winner picked: ${_truncateAddress(winner)}.',
        dedupeKey: 'payout_pick_winner_success',
      );
    } else if (pools.errorMessage != null) {
      AppSnackbarService.instance.error(
        message: pools.errorMessage!,
        dedupeKey: 'payout_pick_winner_failed',
      );
    }

    final authWallet = context.read<AuthProvider>().walletAddress;
    if (authWallet != null) {
      await context.read<WalletProvider>().refreshAfterTx(authWallet);
    }
    await pools.loadPool(widget.poolId);
  }

  Future<void> _releasePayout(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    if (_isReleasingPayout) return;
    final onChainPoolId = pool['onChainPoolId'] as int?;
    if (onChainPoolId == null) {
      AppSnackbarService.instance.warning(
        message: 'Pool not yet deployed on-chain.',
        dedupeKey: 'payout_release_no_chain_id',
      );
      return;
    }

    final winnerWallet = pool['currentRoundWinner']?.toString() ??
        pool['activeRound']?['winnerWallet']?.toString();
    if (winnerWallet == null || winnerWallet.isEmpty) {
      AppSnackbarService.instance.warning(
        message: 'No winner to release payout to.',
        dedupeKey: 'payout_release_no_winner',
      );
      return;
    }

    final members = pool['members'] as List? ?? [];
    final contributionAmount =
        double.tryParse(pool['contributionAmount']?.toString() ?? '0') ?? 0;
    final totalPrize = contributionAmount * members.length;

    setState(() => _isReleasingPayout = true);

    final txHash = await pools.buildAndSignScheduleStream(
      onChainPoolId: onChainPoolId,
      beneficiary: winnerWallet,
      total: totalPrize.toStringAsFixed(0),
      upfrontPercent: pool['season']?['payoutSplitPct'] ?? 20,
      totalRounds: pool['maxMembers'] ?? members.length,
    );

    if (!mounted) return;
    setState(() => _isReleasingPayout = false);

    if (txHash == null) {
      AppSnackbarService.instance.error(
        message: pools.errorMessage ?? 'Failed to release payout.',
        dedupeKey: 'payout_release_failed',
      );
      return;
    }

    AppSnackbarService.instance.success(
      message: 'Payout stream scheduled!',
      dedupeKey: 'payout_release_success',
    );
    await pools.loadPool(widget.poolId);
  }

  Future<void> _showConfigureNextSeasonDialog(
    PoolProvider pools,
    WalletService wallet,
    Map<String, dynamic> pool,
  ) async {
    final season = pool['season'] as Map<String, dynamic>?;
    final contributionController = TextEditingController(
      text: (season?['contributionAmount'] ?? pool['contributionAmount'] ?? '')
          .toString(),
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
                          final caller =
                              context.read<AuthProvider>().walletAddress ??
                                  wallet.walletAddress;
                          if (caller == null || caller.isEmpty) {
                            AppSnackbarService.instance.warning(
                              message:
                                  'Connect wallet to configure next season.',
                              dedupeKey: 'payout_next_season_no_caller',
                            );
                            return;
                          }

                          setState(() => _isCreatingSeason = true);
                          setDialogState(() {});
                          final result = await pools.createNextSeason(
                            poolId: widget.poolId,
                            caller: caller,
                            contributionAmount:
                                contributionController.text.trim(),
                            token: tokenController.text.trim(),
                            payoutSplitPct: int.tryParse(
                                payoutSplitController.text.trim()),
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

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final embeddedDesktop = widget.embeddedDesktop && AppTheme.isDesktop(context);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: embeddedDesktop
            ? null
            : AppBar(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Lottery Payouts'),
                    Text(
                      'SMART CONTRACT VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: isDark ? AppTheme.darkSecondary : AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.casino_rounded,
                        size: 22, color: AppTheme.textSecondaryColor(context)),
                    onPressed: () =>
                        context.read<PoolProvider>().loadPool(widget.poolId),
                  ),
                ],
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
                          color: AppTheme.textTertiaryColor(context)
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        poolProvider.errorMessage ?? 'Equb not found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final contributionAmount = double.tryParse(
                    pool['contributionAmount']?.toString() ?? '0') ??
                0;
            final maxMembers = pool['maxMembers'] ?? 10;
            final currentRound = pool['currentRound'] ?? 0;
            final totalRounds = maxMembers is int
                ? maxMembers
                : (maxMembers as num).toInt();
            final members = pool['members'] as List? ?? [];
            final memberCount = members.length;
            final totalAmount = contributionAmount * memberCount;
            final season = pool['season'] as Map<String, dynamic>?;
            final completedRounds = season?['completedRounds'] ?? 0;
            final seasonComplete = (pool['seasonComplete'] == true) ||
                ((season?['status']?.toString() ?? '').toLowerCase() ==
                    'completed');
            final status = pool['status']?.toString() ?? 'pending-onchain';
            final roundClosedWinnerPending =
                status.toLowerCase() == 'round-closed' && !seasonComplete;
            final currentRoundWinner =
                pool['currentRoundWinner']?.toString() ??
                    pool['activeRound']?['winnerWallet']?.toString();
            final isPoolAdmin = _isPoolAdmin(
                pool, auth.walletAddress, wallet.walletAddress);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (embeddedDesktop) ...[
                        DesktopSectionTitle(
                          title: 'Lottery Payouts',
                          subtitle: 'Draw status, payout history, and winner actions aligned for desktop.',
                          trailing: IconButton(
                            icon: Icon(Icons.casino_rounded,
                                size: 22,
                                color: AppTheme.textSecondaryColor(context)),
                            onPressed: () =>
                                context.read<PoolProvider>().loadPool(widget.poolId),
                          ),
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                      ],
                      _buildHeroDrawingCard(
                        context,
                        currentRound: currentRound,
                        totalAmount: totalAmount,
                        status: status,
                        isRandomizing: _isRandomizing,
                        revealedWinner: _revealedWinner,
                        currentRoundWinner: currentRoundWinner,
                        randomizingDisplay: _randomizingDisplay,
                        seasonComplete: seasonComplete,
                      ),
                      const SizedBox(height: 16),

                      _buildStatRow(
                        context,
                        completedRounds: completedRounds is int
                            ? completedRounds
                            : (completedRounds as num).toInt(),
                        totalRounds: totalRounds,
                        pendingMembers: memberCount -
                            (completedRounds is int
                                ? completedRounds
                                : (completedRounds as num).toInt()),
                      ),
                      const SizedBox(height: 24),

                      _buildPayoutHistoryHeader(context),
                      const SizedBox(height: 12),
                      _buildFilterChips(context),
                      const SizedBox(height: 16),

                      ..._buildFilteredTimeline(
                        context,
                        pool: pool,
                        members: members,
                        totalRounds: totalRounds,
                        currentRound: currentRound,
                        contributionAmount: contributionAmount,
                        memberCount: memberCount,
                        auth: auth,
                        wallet: wallet,
                      ),

                      if (seasonComplete) ...[
                        const SizedBox(height: 20),
                        _buildSeasonCompleteCard(
                          context,
                          season: season,
                          isPoolAdmin: isPoolAdmin,
                          wallet: wallet,
                          poolProvider: poolProvider,
                          pool: pool,
                        ),
                      ],
                    ],
                  ),
                ),

                if (isPoolAdmin)
                  _buildAdminBottomBar(
                    context,
                    pool: pool,
                    poolProvider: poolProvider,
                    wallet: wallet,
                    roundClosedWinnerPending: roundClosedWinnerPending,
                    seasonComplete: seasonComplete,
                    currentRoundWinner: currentRoundWinner,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Hero Drawing Card ──────────────────────────────────────────────────

  Widget _buildHeroDrawingCard(
    BuildContext context, {
    required int currentRound,
    required double totalAmount,
    required String status,
    required bool isRandomizing,
    required String? revealedWinner,
    required String? currentRoundWinner,
    required String randomizingDisplay,
    required bool seasonComplete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = isRandomizing ||
        status.toLowerCase() == 'round-closed' ||
        _isPickingWinner;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isLive
              ? (isDark ? AppTheme.darkPrimary : AppTheme.secondaryColor)
                  .withValues(alpha: 0.4)
              : AppTheme.textHintColor(context).withValues(alpha: 0.2),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadowFor(context),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                if (isLive)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.positive
                            .withValues(alpha: _pulseAnimation.value),
                      ),
                    ),
                  ),
                if (isLive) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLive
                        ? 'LIVE DRAWING · ROUND $currentRound'
                        : seasonComplete
                            ? 'SEASON COMPLETE'
                            : 'ROUND $currentRound',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isLive
                          ? AppTheme.positive
                          : AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.textHintColor(context)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.casino_rounded,
                      size: 18, color: AppTheme.textSecondaryColor(context)),
                ),
              ],
            ),
          ),

          // Status + animation
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusDisplay(
                  context,
                  isRandomizing: isRandomizing,
                  revealedWinner: revealedWinner,
                  currentRoundWinner: currentRoundWinner,
                  randomizingDisplay: randomizingDisplay,
                  seasonComplete: seasonComplete,
                  status: status,
                ),
              ],
            ),
          ),

          // Pool Prize banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkPrimary : AppTheme.positive)
                  .withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.positive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      size: 16, color: AppTheme.positive),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POOL PRIZE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ),
                    Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'EST. WINNER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ),
                    Text(
                      isRandomizing ? 'Drawing...' : 'Round $currentRound',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplay(
    BuildContext context, {
    required bool isRandomizing,
    required String? revealedWinner,
    required String? currentRoundWinner,
    required String randomizingDisplay,
    required bool seasonComplete,
    required String status,
  }) {
    if (isRandomizing) {
      return Column(
        children: [
          Text(
            'Randomizing . . .',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: 1.5,
            ),
          ),
          if (randomizingDisplay.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              randomizingDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppTheme.positive,
              ),
            ),
          ],
        ],
      );
    }

    if (revealedWinner != null) {
      return Column(
        children: [
          const Icon(Icons.celebration_rounded,
              size: 32, color: AppTheme.accentYellow),
          const SizedBox(height: 6),
          const Text(
            'Winner!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.positive,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _truncateAddress(revealedWinner),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      );
    }

    if (currentRoundWinner != null && currentRoundWinner.isNotEmpty) {
      return Column(
        children: [
          Text(
            'Last Winner',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _truncateAddress(currentRoundWinner),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      );
    }

    if (seasonComplete) {
      return Text(
        'All Rounds Complete',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryColor(context),
        ),
      );
    }

    return Text(
      _isPickingWinner ? 'Processing . . .' : 'Waiting for Draw',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondaryColor(context),
      ),
    );
  }

  // ── Stat Row ───────────────────────────────────────────────────────────

  Widget _buildStatRow(
    BuildContext context, {
    required int completedRounds,
    required int totalRounds,
    required int pendingMembers,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.check_circle_rounded,
            iconColor: AppTheme.positive,
            label: 'PAID WINNERS',
            value: '$completedRounds / $totalRounds',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.groups_rounded,
            iconColor: AppTheme.accentYellow,
            label: 'PENDING WINS',
            value: '$pendingMembers Members',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Payout History ─────────────────────────────────────────────────────

  Widget _buildPayoutHistoryHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Payout History',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.positive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.positive,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'ON-CHAIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.positive,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['All', 'Paid', 'Pending', 'Upcoming'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _historyFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _historyFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? AppTheme.darkPrimary
                          : AppTheme.primaryColor)
                      : AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive ? null : AppTheme.subtleShadowFor(context),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildFilteredTimeline(
    BuildContext context, {
    required Map<String, dynamic> pool,
    required List members,
    required int totalRounds,
    required int currentRound,
    required double contributionAmount,
    required int memberCount,
    required AuthProvider auth,
    required WalletService wallet,
  }) {
    final entries = <Widget>[];

    for (int i = 0; i < totalRounds; i++) {
      final roundNum = i + 1;
      final isPaid = roundNum < currentRound;
      final isCurrent = roundNum == currentRound;
      final isPending = roundNum > currentRound;

      if (_historyFilter == 'Paid' && !isPaid) continue;
      if (_historyFilter == 'Pending' && !isCurrent) continue;
      if (_historyFilter == 'Upcoming' && !isPending) continue;

      final memberIdx = i < members.length ? i : null;
      final memberAddr = memberIdx != null
          ? (members[memberIdx] is Map
              ? members[memberIdx]['walletAddress']?.toString() ?? ''
              : members[memberIdx].toString())
          : '';
      final isCurrentUser = memberAddr.isNotEmpty &&
          (memberAddr.toLowerCase() ==
                  (auth.walletAddress ?? '').toLowerCase() ||
              memberAddr.toLowerCase() ==
                  (wallet.walletAddress ?? '').toLowerCase());
      final isLast = i == totalRounds - 1;

      entries.add(
        _buildTimelineEntry(
          context,
          roundNum: roundNum,
          address: memberAddr,
          amount: contributionAmount * memberCount,
          isPaid: isPaid,
          isCurrent: isCurrent,
          isPending: isPending,
          isCurrentUser: isCurrentUser,
          isLast: isLast,
        ),
      );
    }

    if (entries.isEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No rounds match this filter.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ),
        ),
      );
    }

    return entries;
  }

  Widget _buildTimelineEntry(
    BuildContext context, {
    required int roundNum,
    required String address,
    required double amount,
    required bool isPaid,
    required bool isCurrent,
    required bool isPending,
    required bool isCurrentUser,
    required bool isLast,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color dotColor;
    IconData dotIcon;
    if (isPaid) {
      dotColor = AppTheme.successColor;
      dotIcon = Icons.check_rounded;
    } else if (isCurrent) {
      dotColor = isDark ? AppTheme.darkAccent : AppTheme.accentYellow;
      dotIcon = Icons.casino_rounded;
    } else {
      dotColor = AppTheme.textHintColor(context);
      dotIcon = Icons.radio_button_unchecked;
    }

    final displayName = address.isEmpty
        ? (isCurrent ? 'Upcoming Draw' : 'Round $roundNum')
        : isPaid
            ? _truncateAddress(address)
            : isCurrentUser
                ? 'You'
                : _truncateAddress(address);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPending
                        ? dotColor.withValues(alpha: 0.2)
                        : dotColor,
                  ),
                  child: Icon(dotIcon, size: 14, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isPaid
                          ? AppTheme.successColor.withValues(alpha: 0.3)
                          : AppTheme.textHintColor(context)
                              .withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.cardColor(context)
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppTheme.cardRadiusSmall),
                boxShadow:
                    isCurrent ? AppTheme.subtleShadowFor(context) : null,
                border: isCurrent
                    ? Border.all(
                        color: (isDark
                                ? AppTheme.darkPrimary
                                : AppTheme.secondaryColor)
                            .withValues(alpha: 0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            if (isPaid)
                              Text(
                                'ROUND $roundNum WINNER',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppTheme.positive,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Text(
                          'Round $roundNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textTertiaryColor(context),
                          ),
                        ),
                      if (isPaid)
                        Text(
                          '\$${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.positive,
                          ),
                        ),
                    ],
                  ),

                  if (isCurrent) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12,
                            color: AppTheme.textTertiaryColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildBadge(context, 'WINNER PENDING',
                            AppTheme.accentYellow),
                        _buildBadge(
                            context, 'FAIR-PICK GUARANTEED', AppTheme.positive),
                      ],
                    ),
                  ],

                  if (isPaid) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 12, color: AppTheme.positive),
                        const SizedBox(width: 4),
                        Text(
                          'Drawn · Round $roundNum',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isPending && !isCurrent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for smart contract...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textHintColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildBadge(
                        context, 'WINNER PENDING', AppTheme.textHintColor(context)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }

  // ── Season Complete Card ───────────────────────────────────────────────

  Widget _buildSeasonCompleteCard(
    BuildContext context, {
    required Map<String, dynamic>? season,
    required bool isPoolAdmin,
    required WalletService wallet,
    required PoolProvider poolProvider,
    required Map<String, dynamic> pool,
  }) {
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
          Text(
            'Season Complete',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed ${season?['completedRounds'] ?? 0} / ${season?['totalRounds'] ?? 0} rounds.',
            style: TextStyle(
                color: AppTheme.textSecondaryColor(context)),
          ),
          const SizedBox(height: 12),
          if (isPoolAdmin && wallet.isConnected)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showConfigureNextSeasonDialog(
                    poolProvider, wallet, pool),
                child: const Text('Configure Next Season'),
              ),
            ),
        ],
      ),
    );
  }

  // ── Admin Bottom Bar ───────────────────────────────────────────────────

  Widget _buildAdminBottomBar(
    BuildContext context, {
    required Map<String, dynamic> pool,
    required PoolProvider poolProvider,
    required WalletService wallet,
    required bool roundClosedWinnerPending,
    required bool seasonComplete,
    required String? currentRoundWinner,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPickWinner = wallet.isConnected &&
        roundClosedWinnerPending &&
        !_isPickingWinner &&
        !poolProvider.isLoading;
    final canRelease = wallet.isConnected &&
        currentRoundWinner != null &&
        currentRoundWinner.isNotEmpty &&
        !_isReleasingPayout;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (seasonComplete)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: wallet.isConnected
                    ? () => _showConfigureNextSeasonDialog(
                        poolProvider, wallet, pool)
                    : null,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Configure Next Season',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: canPickWinner
                          ? () => _pickWinnerOnChain(
                              poolProvider, wallet, pool)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.accentYellow,
                        foregroundColor:
                            isDark ? AppTheme.darkBackground : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _isPickingWinner
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? AppTheme.darkBackground
                                    : Colors.white,
                              ),
                            )
                          : const Icon(Icons.casino_rounded, size: 18),
                      label: Text(
                        _isPickingWinner ? 'Drawing...' : 'Pick Winner',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: canRelease
                          ? () => _releasePayout(
                              poolProvider, wallet, pool)
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: canRelease
                              ? (isDark
                                  ? AppTheme.darkPrimary
                                  : AppTheme.secondaryColor)
                              : AppTheme.textHintColor(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isReleasingPayout
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isReleasingPayout ? 'Sending...' : 'Release Payout',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
