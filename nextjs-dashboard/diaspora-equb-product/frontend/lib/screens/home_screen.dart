import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/network_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/notification_provider.dart';
import '../services/api_client.dart';
import '../widgets/desktop_dashboard_panels.dart';
import '../widgets/desktop_layout.dart';

// Controls which desktop composition this screen should render.
// Mobile always uses the default `full` layout, while desktop shells can
// request a narrower subset or the unified dashboard grid.
enum DesktopHomeMode { full, leftPanel, middlePanel, unifiedDesktop }

class HomeScreen extends StatefulWidget {
  final DesktopHomeMode desktopMode;

  const HomeScreen({super.key, this.desktopMode = DesktopHomeMode.full});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Wallet UI state.
  bool _balanceVisible = true;
  bool _initialLoadDone = false;
  String? _lastLoadedWallet;
  String _selectedEqubType = 'All';
  String _selectedTimeRange = '30d';

  // Cached analytics payloads used by the dashboard cards.
  Map<String, dynamic>? _globalStats;
  Map<String, dynamic>? _trending;
  List<dynamic>? _leaderboard;
  List<double> _chartPoints = [];
  bool _statsLoading = false;

  // UI filter options for the analytics section.
  static const _equbTypes = [
    'All',
    'Finance',
    'House',
    'Car',
    'Travel',
    'Special'
  ];
  static const _equbTypeMap = {
    'All': null,
    'Finance': 0,
    'House': 1,
    'Car': 2,
    'Travel': 3,
    'Special': 4,
  };
  static const _timeRanges = ['7d', '30d', '90d', '1y'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();

    // Reload wallet-scoped data only when the connected wallet changes.
    if (auth.walletAddress != null &&
        _lastLoadedWallet != auth.walletAddress &&
        mounted) {
      _lastLoadedWallet = auth.walletAddress;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadWalletData();
      });
    } else if (auth.walletAddress == null) {
      _lastLoadedWallet = null;
    }

    // Fetch global analytics once on first entry, even without a wallet.
    if (_globalStats == null && !_statsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPerformanceData();
      });
    }
  }

  void _loadWalletData() {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    final network = context.read<NetworkProvider>();

    // Wallet balances depend on both the active account and active network.
    if (auth.walletAddress != null) {
      wallet.loadAll(auth.walletAddress!, nativeSymbol: network.nativeSymbol);
    }

    // Refresh analytics alongside wallet data so the dashboard stays coherent.
    _loadPerformanceData();
  }

  // Converts the chart filter label into the API time window.
  int _timeRangeToDays(String range) {
    switch (range) {
      case '7d':
        return 7;
      case '30d':
        return 30;
      case '90d':
        return 90;
      case '1y':
        return 365;
      default:
        return 30;
    }
  }

  Future<void> _loadPerformanceData() async {
    if (_statsLoading) return;
    setState(() => _statsLoading = true);

    final api = context.read<ApiClient>();
    final typeCode = _equbTypeMap[_selectedEqubType];
    final days = _timeRangeToDays(_selectedTimeRange);
    final now = DateTime.now().millisecondsSinceEpoch;
    final from = now - (days * 24 * 60 * 60 * 1000);

    try {
      // Fetch all dashboard analytics in parallel so the screen updates as one
      // coherent snapshot instead of flickering card-by-card.
      final results = await Future.wait([
        api.getEqubGlobalStats(type: typeCode),
        api.getEqubTrending(),
        api.getEqubLeaderboard(type: typeCode, limit: 5, sort: 'members'),
        api.getEqubPopularSeries(
          from: from,
          to: now,
          metric: 'contributions',
          limit: 10,
          bucket: days <= 14 ? 'hour' : 'day',
        ),
      ]);
      if (!mounted) return;

      final seriesData = results[3] as Map<String, dynamic>;
      final seriesList = (seriesData['series'] as List?) ?? [];

      // Merge multiple returned series into one cumulative chart so the home
      // screen can show a single simple trend line.
      final bucketMap = <int, double>{};
      for (final s in seriesList) {
        final points = (s['points'] as List?) ?? [];
        for (final p in points) {
          final ts = (p['ts'] as num?)?.toInt() ?? 0;
          final value = (p['value'] as num?)?.toDouble() ?? 0;
          bucketMap[ts] = (bucketMap[ts] ?? 0) + value;
        }
      }

      List<double> chartPts = [];
      if (bucketMap.isNotEmpty) {
        final sorted = bucketMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        double cumulative = 0;
        for (final entry in sorted) {
          cumulative += entry.value;
          chartPts.add(cumulative);
        }
      }

      setState(() {
        _globalStats = results[0] as Map<String, dynamic>;
        _trending = results[1] as Map<String, dynamic>;
        _leaderboard = results[2] as List<dynamic>;
        _chartPoints = chartPts;
        _statsLoading = false;
        _initialLoadDone = true;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Failed to load performance data: $e');
      if (mounted) {
        setState(() {
          _statsLoading = false;
          _initialLoadDone = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, AuthProvider>(
      builder: (context, wallet, auth, _) {
        // This guards against the case where the widget rebuilds before the
        // initial wallet payload has been fetched for the current address.
        if (auth.walletAddress != null &&
            wallet.transactions.isEmpty &&
            !wallet.isLoading &&
            _lastLoadedWallet != auth.walletAddress) {
          _lastLoadedWallet = auth.walletAddress;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            wallet.loadAll(auth.walletAddress!);
          });
        }

        final mode = widget.desktopMode;

        // Desktop shells can request specialized dashboard slices instead of
        // the standard mobile-first composition below.
        if (mode == DesktopHomeMode.unifiedDesktop) {
          return _buildUnifiedDesktopContent(context, wallet, auth);
        }
        if (mode == DesktopHomeMode.leftPanel) {
          return _buildLeftPanelContent(context, wallet, auth);
        }
        if (mode == DesktopHomeMode.middlePanel) {
          return _buildMiddlePanelContent(context, wallet);
        }

        final showSkeleton =
            !_initialLoadDone && (wallet.isLoading || _statsLoading);

        // Show a placeholder only for the first load. Later refreshes should
        // keep the existing content visible to avoid jarring layout shifts.
        if (showSkeleton) {
          return _buildSkeletonBody(context);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildHeader(context, auth),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (auth.walletAddress != null) {
                    final net = context.read<NetworkProvider>();
                    await wallet.loadAll(auth.walletAddress!,
                        nativeSymbol: net.nativeSymbol);
                  }
                  await _loadPerformanceData();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardRadius),
                          boxShadow: AppTheme.cardShadowFor(context),
                        ),
                        child: Column(
                          children: [
                            _buildBalanceCard(context, wallet),
                            _buildTokenSelector(context, wallet, auth),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 24),
                              child: _buildQuickActions(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildPerformanceSection(context),
                      const SizedBox(height: 28),
                      _buildTransactionsSection(context, wallet),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonBody(BuildContext context) {
    final base = AppTheme.textHintColor(context).withValues(alpha: 0.25);
    final highlight = AppTheme.cardColor(context);

    Widget bone(double width, double height, {double radius = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                bone(44, 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bone(120, 14),
                      const SizedBox(height: 6),
                      bone(180, 10),
                    ],
                  ),
                ),
                bone(36, 36, radius: 18),
              ],
            ),
            const SizedBox(height: 20),
            // Balance card skeleton
            bone(double.infinity, 180, radius: 24),
            const SizedBox(height: 16),
            // Token selector skeleton
            bone(double.infinity, 56, radius: 16),
            const SizedBox(height: 20),
            // Quick actions skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                  4,
                  (_) => Column(
                        children: [
                          bone(48, 48, radius: 24),
                          const SizedBox(height: 8),
                          bone(40, 10),
                        ],
                      )),
            ),
            const SizedBox(height: 32),
            // Performance section skeleton
            bone(140, 16),
            const SizedBox(height: 12),
            bone(double.infinity, 120, radius: 16),
            const SizedBox(height: 28),
            // Transaction list skeleton
            bone(120, 16),
            const SizedBox(height: 12),
            ...List.generate(
                4,
                (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          bone(40, 40, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bone(140, 12),
                                const SizedBox(height: 6),
                                bone(90, 10),
                              ],
                            ),
                          ),
                          bone(60, 14),
                        ],
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanelContent(
      BuildContext context, WalletProvider wallet, AuthProvider auth) {
    // Used by split desktop layouts where overview and analytics live in the
    // main column and secondary panels render elsewhere.
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Dashboard Overview',
            subtitle:
                'Balance, actions, and Equb momentum aligned for desktop.',
          ),
          const SizedBox(height: 16),
          _buildDesktopOverviewGrid(context, wallet, auth),
          const SizedBox(height: AppTheme.desktopSectionGap),
          _buildDesktopPerformanceGrid(context),
        ],
      ),
    );
  }

  Widget _buildUnifiedDesktopContent(
      BuildContext context, WalletProvider wallet, AuthProvider auth) {
    // This is the current desktop-first home experience: one scroll surface,
    // one responsive grid, and no separate right rail.
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Dashboard Overview',
            subtitle:
                'Balance, actions, activity, and Equb momentum aligned in one desktop workspace grid.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // The grid uses span-based sizing so important modules can take
              // two columns on larger screens while still collapsing cleanly.
              final columns = constraints.maxWidth >= 1320
                  ? 3
                  : constraints.maxWidth >= 920
                      ? 2
                      : 1;
              final gap = AppTheme.desktopPanelGap;
              final columnWidth =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;

              double spanWidth(int span) =>
                  (columnWidth * span) + (gap * (span - 1));

              final balanceModule = DesktopCardSection(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildBalanceCard(context, wallet),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: _buildTokenSelector(context, wallet, auth),
                    ),
                  ],
                ),
              );

              final actionsModule = DesktopCardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your most-used wallet and Equb shortcuts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    _buildQuickActions(
                      context,
                      forceGrid: true,
                      compactCards: true,
                    ),
                  ],
                ),
              );

              final performanceModule = DesktopCardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Global Equb Performance',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => context.push('/equb-insights'),
                          child: Text(
                            'See All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textTertiaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTypeChips(context),
                    const SizedBox(height: 16),
                    _buildMetricsRow(context),
                    const SizedBox(height: 16),
                    _buildPerformanceChart(context),
                  ],
                ),
              );

              final trendsModule = DesktopCardSection(
                child: _buildTrendingEqubs(context),
              );

              final leaderboardModule = DesktopCardSection(
                child: _buildLeaderboard(context),
              );

              final transactionsModule = DesktopCardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DesktopSectionTitle(
                      title: 'Transactions Overview',
                      subtitle:
                          'Settlement history and recent wallet movements',
                    ),
                    const SizedBox(height: 16),
                    _buildTransactionsSection(context, wallet),
                  ],
                ),
              );

              // Module order matters because `Wrap` flows left-to-right and
              // top-to-bottom. The sequence below defines the dashboard story.
              final items = <Widget>[
                SizedBox(
                  width: spanWidth(columns == 1 ? 1 : 2),
                  child: balanceModule,
                ),
                SizedBox(width: spanWidth(1), child: actionsModule),
                SizedBox(
                    width: spanWidth(1),
                    child: const DesktopWorkspaceStatusCard()),
                SizedBox(
                  width: spanWidth(columns == 1 ? 1 : 2),
                  child: const DesktopQuickTransferCard(),
                ),
                SizedBox(
                    width: spanWidth(1), child: const DesktopShortcutsCard()),
                SizedBox(
                  width: spanWidth(columns == 1 ? 1 : 2),
                  child: performanceModule,
                ),
                SizedBox(width: spanWidth(1), child: leaderboardModule),
                SizedBox(width: spanWidth(1), child: trendsModule),
                SizedBox(
                    width: spanWidth(1),
                    child: const DesktopRecentActivityCard()),
                SizedBox(
                  width: spanWidth(columns == 1 ? 1 : 2),
                  child: transactionsModule,
                ),
              ];

              return Wrap(
                spacing: gap,
                runSpacing: AppTheme.desktopSectionGap,
                children: items,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiddlePanelContent(BuildContext context, WalletProvider wallet) {
    // Used by older split desktop compositions where transactions occupy the
    // central content column.
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Transactions Overview',
            subtitle: 'Settlement history and recent wallet movements',
          ),
          const SizedBox(height: 16),
          _buildTransactionsSection(context, wallet),
        ],
      ),
    );
  }

  Widget _buildDesktopOverviewGrid(
      BuildContext context, WalletProvider wallet, AuthProvider auth) {
    // Legacy two-module desktop overview kept for narrower shell variants.
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumnCards = constraints.maxWidth >= 500;
        final useWideSplit = constraints.maxWidth >= 760;

        final balanceModule = DesktopCardSection(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildBalanceCard(context, wallet),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _buildTokenSelector(context, wallet, auth),
              ),
            ],
          ),
        );

        final actionsModule = DesktopCardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Your most-used wallet and Equb shortcuts',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              _buildQuickActions(
                context,
                forceGrid: true,
                compactCards: true,
              ),
            ],
          ),
        );

        if (!useTwoColumnCards) {
          return Column(
            children: [
              balanceModule,
              const SizedBox(height: AppTheme.desktopSectionGap),
              actionsModule,
            ],
          );
        }

        if (!useWideSplit) {
          final moduleWidth =
              (constraints.maxWidth - AppTheme.desktopPanelGap) / 2;

          return Wrap(
            spacing: AppTheme.desktopPanelGap,
            runSpacing: AppTheme.desktopSectionGap,
            children: [
              SizedBox(width: moduleWidth, child: balanceModule),
              SizedBox(width: moduleWidth, child: actionsModule),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: balanceModule),
            const SizedBox(width: AppTheme.desktopPanelGap),
            Expanded(flex: 5, child: actionsModule),
          ],
        );
      },
    );
  }

  Widget _buildDesktopPerformanceGrid(BuildContext context) {
    // Legacy desktop analytics composition kept for split shell variants.
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitSecondary = constraints.maxWidth >= 460;

        final performanceOverview = DesktopCardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Global Equb Performance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => context.push('/equb-insights'),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTypeChips(context),
              const SizedBox(height: 16),
              _buildMetricsRow(context),
              const SizedBox(height: 16),
              _buildPerformanceChart(context),
            ],
          ),
        );

        final trendsModule = DesktopCardSection(
          child: _buildTrendingEqubs(context),
        );

        final leaderboardModule = DesktopCardSection(
          child: _buildLeaderboard(context),
        );

        if (!splitSecondary) {
          return Column(
            children: [
              performanceOverview,
              const SizedBox(height: AppTheme.desktopSectionGap),
              trendsModule,
              const SizedBox(height: AppTheme.desktopSectionGap),
              leaderboardModule,
            ],
          );
        }

        return Column(
          children: [
            performanceOverview,
            const SizedBox(height: AppTheme.desktopSectionGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: trendsModule),
                const SizedBox(width: AppTheme.desktopPanelGap),
                Expanded(child: leaderboardModule),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    // Mobile/tablet header. Desktop unified mode does not use this header.
    final name = auth.walletAddress != null
        ? '${auth.walletAddress!.substring(0, 6)}...'
        : 'User';
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.3),
              border: Border.all(
                  color: Theme.of(context).colorScheme.surface, width: 2),
            ),
            child: Icon(
              Icons.person,
              size: 22,
              color: AppTheme.buttonTextColor(context).withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text('Hi, $name!',
              style: Theme.of(context).textTheme.headlineLarge,
              overflow: TextOverflow.ellipsis),
        ),
        _buildNetworkToggle(context),
        const SizedBox(width: 4),
        const Spacer(),
        GestureDetector(
          onTap: () => context.push('/equb-insights'),
          child: _buildHeaderIcon(context, Icons.show_chart_rounded),
        ),
        const SizedBox(width: 8),
        _buildNotificationBell(context),
        const SizedBox(width: 8),
        GestureDetector(
            onTap: _loadWalletData,
            child: _buildHeaderIcon(context, Icons.sync_rounded)),
      ],
    );
  }

  Widget _buildNetworkToggle(BuildContext context) {
    final network = context.watch<NetworkProvider>();
    final isTestnet = network.isTestnet;
    final color = isTestnet ? AppTheme.warningColor : AppTheme.positive;

    return GestureDetector(
      onTap: () async {
        final auth = context.read<AuthProvider>();
        final wallet = context.read<WalletProvider>();
        final address = auth.walletAddress;
        await network.toggleNetwork();
        if (!mounted) return;
        if (address != null) {
          // Reload after switching chain so balances and symbols stay aligned
          // with the new network context.
          unawaited(
              wallet.loadAll(address, nativeSymbol: network.nativeSymbol));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              network.shortNetworkName.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.swap_vert, size: 10, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(BuildContext context, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: AppTheme.textPrimaryColor(context)),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHeaderIcon(context, Icons.notifications_outlined),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: AppTheme.dangerColor, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector(
      BuildContext context, WalletProvider wallet, AuthProvider auth) {
    // The wallet provider exposes balances per supported stablecoin and this
    // segmented control switches the active one for the balance card.
    final tokens = ['USDC', 'USDT'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppTheme.darkSurface : AppTheme.backgroundLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: tokens.map((t) {
            final isSelected = wallet.token == t;
            final bal = wallet.balanceOf(t);
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    wallet.selectToken(t, walletAddress: auth.walletAddress),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.cardColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: AppTheme.textPrimaryColor(context)
                                    .withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.textPrimaryColor(context)
                                  : AppTheme.textTertiaryColor(context),
                            )),
                        const SizedBox(width: 6),
                        Text('\$$bal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.textSecondaryColor(context)
                                  : AppTheme.textTertiaryColor(context)
                                      .withValues(alpha: 0.7),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletProvider wallet) {
    // The top balance card is intentionally more visual than the other cards
    // because it anchors the dashboard and communicates wallet status first.
    final rawBalance = wallet.balance;
    final balanceNum = double.tryParse(rawBalance) ?? 0.0;
    final balanceFormatted = _formatBalance(balanceNum);

    String exchangeRate = '';
    if (wallet.rates.isNotEmpty) {
      final eurRate = wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95';
      final gbpRate = wallet.rates['GBP']?.toStringAsFixed(2) ?? '0.79';
      exchangeRate = '1 USD = EUR $eurRate = GBP $gbpRate';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentYellow,
              AppTheme.accentYellow.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _balanceVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: AppTheme.positive),
                        ),
                        const SizedBox(width: 6),
                        Text(wallet.token,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary
                                    .withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  if (exchangeRate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(exchangeRate,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color:
                                  AppTheme.textPrimary.withValues(alpha: 0.4))),
                    ),
                  ],
                  const SizedBox(height: 14),
                  wallet.isLoading
                      ? const SizedBox(
                          height: 36,
                          width: 36,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          _balanceVisible ? '\$$balanceFormatted' : '••••••••',
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -1.0)),
                  const SizedBox(height: 4),
                  Text(wallet.isLoading ? '' : '+\$0.00',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBalance(double balance) {
    // Local formatter to avoid pulling in a heavier dependency for a single
    // currency-style display in the main wallet card.
    final parts = balance.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '$buffer.$decPart';
  }

  Widget _buildQuickActions(BuildContext context,
      {bool forceGrid = false, bool compactCards = false}) {
    // Keep action definitions centralized so both mobile and desktop variants
    // render from the same source of truth.
    final actions = [
      _HomeActionData(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Pay',
        onTap: () => _showPayBottomSheet(context),
      ),
      _HomeActionData(
        icon: Icons.show_chart_rounded,
        label: 'Transfer',
        onTap: () => context.push('/fund-wallet'),
      ),
      _HomeActionData(
        icon: Icons.south_west_rounded,
        label: 'Receive',
        onTap: () => _showReceiveBottomSheet(context),
      ),
      _HomeActionData(
        icon: Icons.groups_rounded,
        label: 'Equb',
        onTap: () => context.push('/pools'),
      ),
      _HomeActionData(
        icon: Icons.shield_outlined,
        label: 'Collateral',
        onTap: () => context.push('/collateral'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Smaller widths use a simple row. Wider desktop cards switch to a
        // grid so labels remain readable and touch targets stay balanced.
        final useGrid = forceGrid || constraints.maxWidth >= 420;
        if (!useGrid) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: actions
                .map((action) => _buildActionButton(
                      context,
                      icon: action.icon,
                      label: action.label,
                      onTap: action.onTap,
                    ))
                .toList(),
          );
        }

        final columns = compactCards
            ? (constraints.maxWidth >= 420 ? 2 : 1)
            : (constraints.maxWidth >= 620 ? 3 : 2);
        const gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map((action) => SizedBox(
                    width: itemWidth,
                    child: _buildActionButton(
                      context,
                      icon: action.icon,
                      label: action.label,
                      onTap: action.onTap,
                      expanded: true,
                      compact: compactCards,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool expanded = false,
      bool compact = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: expanded
            ? EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 12 : 14,
              )
            : EdgeInsets.zero,
        decoration: expanded
            ? BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(18),
                border: AppTheme.borderFor(context, opacity: 0.06),
              )
            : null,
        child: expanded
            ? compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimaryColor(context)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimaryColor(context)
                              .withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ],
                  )
            : Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.textPrimaryColor(context)
                              .withValues(alpha: 0.15),
                          width: 1.5),
                    ),
                    child: Icon(icon,
                        size: 22, color: AppTheme.textPrimaryColor(context)),
                  ),
                  const SizedBox(height: 10),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimaryColor(context))),
                ],
              ),
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context) {
    // Mobile/tablet analytics layout. Desktop unified mode composes these
    // building blocks into its own larger grid.
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitLayout = constraints.maxWidth >= 620;

        final header = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Global Equb Performance',
                style: Theme.of(context).textTheme.titleLarge),
            GestureDetector(
              onTap: () => context.push('/equb-insights'),
              child: Text('See All',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiaryColor(context))),
            ),
          ],
        );

        final primaryColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeChips(context),
            const SizedBox(height: 16),
            _buildMetricsRow(context),
            const SizedBox(height: 16),
            _buildPerformanceChart(context),
            const SizedBox(height: 20),
            _buildTrendingEqubs(context),
          ],
        );

        if (!splitLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              primaryColumn,
              const SizedBox(height: 20),
              _buildLeaderboard(context),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: primaryColumn,
                ),
                const SizedBox(width: AppTheme.desktopPanelGap),
                Expanded(
                  flex: 4,
                  child: _buildLeaderboard(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeChips(BuildContext context) {
    // Changing the chip updates the server-side filter, then refreshes all
    // analytics panels that depend on the selected Equb category.
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _equbTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = _equbTypes[i];
          final isSelected = _selectedEqubType == type;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedEqubType = type);
              _loadPerformanceData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.buttonColor(context)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.textHintColor(context)),
              ),
              child: Text(type,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.buttonTextColor(context)
                          : AppTheme.textSecondaryColor(context))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    // These are compact summary KPIs derived from the global stats payload.
    if (_statsLoading && _globalStats == null) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final stats = _globalStats;
    final tvlRaw = (stats?['tvl'] as num?)?.toDouble() ?? 0.0;
    final tvl = _formatTvl(tvlRaw);
    final active = (stats?['activeEqubs'] as num?)?.toInt() ?? 0;
    final members = (stats?['totalMembers'] as num?)?.toInt() ?? 0;
    final completion = (stats?['completionRate'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        _metricBox(context, tvl, 'TVL'),
        const SizedBox(width: 8),
        _metricBox(context, '$active', 'Active'),
        const SizedBox(width: 8),
        _metricBox(context, _formatNumber(members), 'Members'),
        const SizedBox(width: 8),
        _metricBox(context, '${completion.toStringAsFixed(1)}%', 'Completion'),
      ],
    );
  }

  String _formatTvl(double tvl) {
    // Shortens large monetary values for dashboard display.
    if (tvl >= 1e9) return '\$${(tvl / 1e9).toStringAsFixed(1)}B';
    if (tvl >= 1e6) return '\$${(tvl / 1e6).toStringAsFixed(1)}M';
    if (tvl >= 1e3) return '\$${(tvl / 1e3).toStringAsFixed(1)}K';
    return '\$${tvl.toStringAsFixed(2)}';
  }

  String _formatNumber(int n) {
    // Matches the compact style used for TVL labels and leaderboard stats.
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _metricBox(BuildContext context, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.subtleShadowFor(context),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context))),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textTertiaryColor(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart(BuildContext context) {
    // The chart is intentionally lightweight: the API data is pre-aggregated
    // in `_loadPerformanceData`, and this widget only handles display.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TVL Growth', style: Theme.of(context).textTheme.labelLarge),
              Row(
                children: _timeRanges.map((r) {
                  final isSelected = _selectedTimeRange == r;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedTimeRange = r);
                      _loadPerformanceData();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.buttonColor(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(r,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.buttonTextColor(context)
                                  : AppTheme.textTertiaryColor(context))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.accentYellow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _chartPoints.length >= 2
                ? CustomPaint(painter: _DataChartPainter(points: _chartPoints))
                : Center(
                    child: _statsLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textTertiaryColor(context),
                            ),
                          )
                        : Text(
                            'No data for this period',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiaryColor(context),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingEqubs(BuildContext context) {
    // The backend returns separate buckets; the UI flattens them into one
    // horizontal scroller while preserving each item's source category.
    final sections = <MapEntry<String, List<dynamic>>>[];
    if (_trending != null) {
      final fg = (_trending!['fastestGrowing'] as List?) ?? [];
      final cs = (_trending!['completingSoon'] as List?) ?? [];
      final nw = (_trending!['newest'] as List?) ?? [];
      if (fg.isNotEmpty) sections.add(MapEntry('Fastest Growing', fg));
      if (cs.isNotEmpty) sections.add(MapEntry('Completing Soon', cs));
      if (nw.isNotEmpty) sections.add(MapEntry('Newest', nw));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trending Equbs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_statsLoading && sections.isEmpty)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (sections.isEmpty)
          Container(
            height: 80,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            ),
            child: Center(
              child: Text('No trending equbs yet',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  sections.fold<int>(0, (sum, s) => sum + s.value.length),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                int idx = i;
                for (final section in sections) {
                  if (idx < section.value.length) {
                    final pool = section.value[idx] as Map<String, dynamic>;
                    return _buildTrendingCard(context, section.key, pool);
                  }
                  idx -= section.value.length;
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTrendingCard(
      BuildContext context, String category, Map<String, dynamic> pool) {
    // Trending cards are intentionally compact and route directly into the
    // pool detail page for fast exploration.
    final poolId = pool['poolId']?.toString() ?? '';
    final onChainId = pool['onChainPoolId'];
    final name = onChainId != null
        ? 'Pool #$onChainId'
        : 'Pool ${poolId.substring(0, 6)}...';
    final members = (pool['currentRound'] as num?)?.toInt() ?? 0;
    final maxMembers = (pool['maxMembers'] as num?)?.toInt() ?? 0;
    final completionPct = (pool['completionPct'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => context.push('/pools/$poolId'),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
          boxShadow: AppTheme.subtleShadowFor(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(category,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context))),
            ),
            const SizedBox(height: 8),
            Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context)),
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                Text('$members/$maxMembers',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context))),
                const Spacer(),
                Text('${completionPct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.positive)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context) {
    // Leaderboard ranking is driven by the backend response order.
    final items = _leaderboard ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equb Leaderboard',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_statsLoading && items.isEmpty)
          const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.leaderboard_rounded,
                      size: 36, color: AppTheme.textTertiaryColor(context)),
                  const SizedBox(height: 8),
                  Text('No leaderboard data yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
              boxShadow: AppTheme.subtleShadowFor(context),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final pool = items[i] as Map<String, dynamic>;
                final onChainId = pool['onChainPoolId'];
                final poolId = pool['poolId']?.toString() ?? '';
                final name = onChainId != null
                    ? 'Pool #$onChainId'
                    : 'Pool ${poolId.length > 6 ? poolId.substring(0, 6) : poolId}...';
                final memberCount = (pool['memberCount'] as num?)?.toInt() ?? 0;
                final completionPct =
                    (pool['completionPct'] as num?)?.toDouble() ?? 0.0;
                final isLast = i == items.length - 1;

                return GestureDetector(
                  onTap: () => context.push('/pools/$poolId'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                  color: AppTheme.textHintColor(context)
                                      .withValues(alpha: 0.2))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < 3
                                ? AppTheme.accentYellow.withValues(alpha: 0.3)
                                : AppTheme.textHintColor(context)
                                    .withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor(context),
                                )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppTheme.textPrimaryColor(context))),
                              Text('$memberCount members',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppTheme.textTertiaryColor(context))),
                            ],
                          ),
                        ),
                        Text('${completionPct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.positive)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionsSection(
      BuildContext context, WalletProvider wallet) {
    // The home screen only previews the most recent transactions to keep the
    // card compact; the full history lives on the dedicated route.
    final txList = wallet.transactions;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text('Latest Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/transactions'),
              child: Text('See All',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiaryColor(context))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadowFor(context),
          ),
          child: txList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                      child: Text(
                          wallet.isLoading
                              ? 'Loading transactions...'
                              : 'No transactions yet',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textTertiaryColor(context)))))
              : Column(
                  children: List.generate(
                    txList.length > 5 ? 5 : txList.length,
                    (i) {
                      final tx = txList[i];
                      final isLast =
                          i == (txList.length > 5 ? 4 : txList.length - 1);
                      return _buildTransactionTile(context, tx, isLast);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, Map<String, dynamic> tx, bool isLast) {
    // Transactions are normalized here into one visual model so token and
    // native transfers can share the same row component.
    final type = tx['type'] as String? ?? 'received';
    final isSent = type == 'sent';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final tokenSymbol = tx['token']?.toString() ?? 'USDC';
    final nativeSym = context.read<NetworkProvider>().nativeSymbol;
    final isNative = tokenSymbol == 'CTC' || tokenSymbol == 'tCTC';
    final isFailed = tx['isError'] == true;
    final amountStr = isNative
        ? '${isSent ? '-' : '+'}${amount.toStringAsFixed(4)} $nativeSym'
        : '${isSent ? r'-$' : r'+$'}${amount.toStringAsFixed(2)}';

    final from = tx['from']?.toString() ?? '';
    final to = tx['to']?.toString() ?? '';
    final displayAddr = isSent ? to : from;
    final name = displayAddr.length > 10
        ? '${displayAddr.substring(0, 6)}...${displayAddr.substring(displayAddr.length - 4)}'
        : displayAddr;

    Color color = isSent ? AppTheme.negative : AppTheme.positive;
    if (isFailed) color = AppTheme.textTertiaryColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color:
                        AppTheme.textHintColor(context).withValues(alpha: 0.35),
                    width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(
                isSent ? Icons.north_east_rounded : Icons.south_west_rounded,
                size: 22,
                color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context))),
                const SizedBox(height: 2),
                Text(tokenSymbol,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiaryColor(context))),
              ],
            ),
          ),
          Text(amountStr,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSent ? AppTheme.negative : AppTheme.positive)),
        ],
      ),
    );
  }

  void _showPayBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHintColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quick Pay',
                        style: Theme.of(context).textTheme.titleLarge),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/pay');
                      },
                      child: const Text('Full Screen',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.accentYellowDark,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Recipient address (0x...)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/pay');
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiveBottomSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final address = auth.walletAddress ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHintColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Receive', style: Theme.of(context).textTheme.titleLarge),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/receive');
                  },
                  child: const Text('Full Screen',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentYellowDark,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                address.isNotEmpty ? address : 'No wallet connected',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimaryColor(context)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text('Share this address to receive tokens',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DataChartPainter extends CustomPainter {
  final List<double> points;

  _DataChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Paint the line and the subtle fill under it.
    final paint = Paint()
      ..color = AppTheme.accentYellowDark.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.accentYellow.withValues(alpha: 0.3),
          AppTheme.accentYellow.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final padding = size.height * 0.08;
    final drawHeight = size.height - padding * 2;

    // Normalize values into a 0..1 range so any dataset can be projected into
    // the available paint area.
    double normalize(double v) {
      if (range == 0) return 0.5;
      return (v - minVal) / range;
    }

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (points.length - 1);

    // Build both the visible trend line and the closed area-fill path in a
    // single pass through the point list.
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = padding + drawHeight * (1 - normalize(points[i]));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw end dot
    final lastX = (points.length - 1) * stepX;
    final lastY = padding + drawHeight * (1 - normalize(points.last));
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = AppTheme.accentYellowDark,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      6,
      Paint()
        ..color = AppTheme.accentYellowDark.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _DataChartPainter oldDelegate) =>
      !_listEquals(oldDelegate.points, points);

  // Custom comparison avoids unnecessary repaints when the point list content
  // is unchanged but a new list instance is created.
  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _HomeActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
