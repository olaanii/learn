import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/network_provider.dart';
import '../providers/pool_provider.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/desktop_layout.dart';

class PoolBrowserScreen extends StatefulWidget {
  const PoolBrowserScreen({super.key});

  @override
  State<PoolBrowserScreen> createState() => _PoolBrowserScreenState();
}

class _PoolBrowserScreenState extends State<PoolBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedFrequency = 'All';
  String _selectedSort = 'Newest';
  bool _initialLoadDone = false;

  static const _categories = [
    'All',
    'Finance',
    'House',
    'Car',
    'Travel',
    'Special',
    'Workplace',
    'Education',
    'Wedding',
    'Emergency',
  ];
  static const _frequencies = ['All', 'Daily', 'Weekly', 'Monthly'];
  static const _sortOptions = [
    'Newest',
    'Most Members',
    'Highest Completion',
    'Contribution Amount',
    'Health Score',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshPools();
      });
    }
  }

  Future<void> _refreshPools() async {
    await context.read<PoolProvider>().loadPools();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isDesktop(context)) {
      return _buildDesktopScreen(context);
    }

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Equbs', style: Theme.of(context).textTheme.headlineLarge),
              _buildCreateButton(context),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accentYellowDark,
            labelColor: AppTheme.textPrimaryColor(context),
            unselectedLabelColor: AppTheme.textTertiaryColor(context),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Browse Equbs'),
              Tab(text: 'My Equbs'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBrowseTab(context),
              _buildMyEqubsTab(context),
            ],
          ),
        ),
      ],
    );

    return content;
  }

  bool get _hasActiveFilters =>
      _selectedCategory != 'All' ||
      _selectedFrequency != 'All' ||
      _selectedSort != 'Newest';

  Widget _buildDesktopScreen(BuildContext context) {
    return DesktopContent(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionTitle(
            title: 'Equbs',
            subtitle:
                'Browse live groups, monitor your memberships, and launch new Equbs from a desktop-first workspace.',
            trailing: _buildCreateButton(context, large: true),
          ),
          const SizedBox(height: AppTheme.desktopSectionGap),
          _buildDesktopOverviewStrip(context),
          const SizedBox(height: AppTheme.desktopSectionGap),
          Expanded(
            child: DesktopCardSection(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Workspace',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.textHintColor(context)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Desktop browse mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.accentYellowDark,
                      labelColor: AppTheme.textPrimaryColor(context),
                      unselectedLabelColor: AppTheme.textTertiaryColor(context),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Browse Equbs'),
                        Tab(text: 'My Equbs'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color:
                        AppTheme.textHintColor(context).withValues(alpha: 0.35),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBrowseTab(context),
                        _buildMyEqubsTab(context),
                      ],
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

  Widget _buildCreateButton(BuildContext context, {bool large = false}) {
    return GestureDetector(
      onTap: () => _showCreateDialog(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 14,
          vertical: large ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.buttonColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              size: large ? 20 : 18,
              color: AppTheme.buttonTextColor(context),
            ),
            const SizedBox(width: 6),
            Text(
              'Create Equb',
              style: TextStyle(
                color: AppTheme.buttonTextColor(context),
                fontSize: large ? 14 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopOverviewStrip(BuildContext context) {
    return Consumer2<PoolProvider, AuthProvider>(
      builder: (context, pool, auth, _) {
        final wallet = auth.walletAddress?.toLowerCase() ?? '';
        final myPools = pool.pools.where((p) {
          final membersList = p['members'] as List? ?? [];
          final memberAddresses = membersList.map((e) {
            if (e is Map) {
              return (e['walletAddress'] ?? '').toString().toLowerCase();
            }
            return e.toString().toLowerCase();
          }).toList();
          final createdBy =
              (p['createdBy'] ?? p['creator'] ?? '').toString().toLowerCase();
          final treasury = (p['treasury'] ?? '').toString().toLowerCase();
          return memberAddresses.contains(wallet) ||
              createdBy == wallet ||
              treasury == wallet;
        }).length;
        final activeCount = pool.pools
            .where((p) => (p['status']?.toString() ?? 'pending') == 'active')
            .length;

        return Row(
          children: [
            Expanded(
              child: _buildDesktopMetricTile(
                context,
                label: 'Visible Equbs',
                value: '${pool.pools.length}',
                detail: 'All groups currently loaded',
                icon: Icons.grid_view_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.desktopPanelGap),
            Expanded(
              child: _buildDesktopMetricTile(
                context,
                label: 'Active Cycles',
                value: '$activeCount',
                detail: 'Pools currently in progress',
                icon: Icons.timeline_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.desktopPanelGap),
            Expanded(
              child: _buildDesktopMetricTile(
                context,
                label: 'My Equbs',
                value: '$myPools',
                detail: 'Groups tied to your wallet',
                icon: Icons.groups_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String detail,
    required IconData icon,
  }) {
    return DesktopCardSection(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.buttonColor(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.buttonColor(context), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseTab(BuildContext context) {
    return Consumer<PoolProvider>(
      builder: (context, pool, _) {
        final pools = _filterPools(pool.pools);
        final desktop = AppTheme.isDesktop(context);
        return Column(
          children: [
            if (desktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText:
                                  'Search by name, creator, or on-chain id',
                              prefixIcon: Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed:
                                pool.isLoading ? null : () => pool.loadPools(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Refresh'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildFilterIconButton(context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDesktopBrowseStatusCard(
                            context,
                            title: 'Results',
                            value: '${pools.length}',
                            caption: _hasActiveFilters
                                ? 'Matching the current desktop filters'
                                : 'All available Equbs in view',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDesktopBrowseStatusCard(
                            context,
                            title: 'Sort',
                            value: _selectedSort,
                            caption: 'Applied across the current results',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDesktopBrowseStatusCard(
                            context,
                            title: 'Frequency',
                            value: _selectedFrequency,
                            caption: 'Filter scope for contribution cadence',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search equbs...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildFilterIconButton(context),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            _buildCategoryChips(horizontalPadding: desktop ? 24 : 20),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 24 : 20,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Text('${pools.length} equbs',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedFrequency = 'All';
                        _selectedSort = 'Newest';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Clear filters',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondaryColor)),
                            SizedBox(width: 4),
                            Icon(Icons.close_rounded,
                                size: 13, color: AppTheme.secondaryColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: pool.isLoading && pool.pools.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : pool.errorMessage != null && pool.pools.isEmpty
                      ? _buildErrorState(context, pool)
                      : pools.isEmpty && pool.pools.isNotEmpty
                          ? _buildEmpty(context, 'No equbs match your filters')
                          : pools.isEmpty
                              ? _buildEmptyWithRefresh(context, pool)
                              : RefreshIndicator(
                                  onRefresh: () => pool.loadPools(),
                                  child: desktop
                                      ? LayoutBuilder(
                                          builder: (context, constraints) {
                                            final columns =
                                                constraints.maxWidth >= 1280
                                                    ? 3
                                                    : 2;
                                            return GridView.builder(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      24, 0, 24, 24),
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: columns,
                                                crossAxisSpacing:
                                                    AppTheme.desktopPanelGap,
                                                mainAxisSpacing: 16,
                                                mainAxisExtent: 250,
                                              ),
                                              itemCount: pools.length,
                                              itemBuilder: (_, i) =>
                                                  _buildEqubCard(
                                                      context, pools[i]),
                                            );
                                          },
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                              20, 0, 20, 20),
                                          itemCount: pools.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (_, i) =>
                                              _buildEqubCard(context, pools[i]),
                                        ),
                                ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterIconButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFilterSheet(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _hasActiveFilters
              ? AppTheme.buttonColor(context)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: _hasActiveFilters
              ? null
              : Border.all(color: AppTheme.textHintColor(context)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 22,
              color: _hasActiveFilters
                  ? AppTheme.buttonTextColor(context)
                  : AppTheme.textSecondaryColor(context),
            ),
            if (_hasActiveFilters)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentYellow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext ctx) {
    var tempFrequency = _selectedFrequency;
    var tempSort = _selectedSort;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Widget chipRow<T>({
              required List<T> items,
              required String Function(T) label,
              required bool Function(T) isSelected,
              required void Function(T) onSelect,
            }) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  final selected = isSelected(item);
                  return GestureDetector(
                    onTap: () => setSheetState(() => onSelect(item)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.buttonColor(ctx)
                            : Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: AppTheme.textHintColor(ctx)),
                      ),
                      child: Text(
                        label(item),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.buttonTextColor(ctx)
                              : AppTheme.textSecondaryColor(ctx),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textHintColor(ctx),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Equbs',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(ctx),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              tempFrequency = 'All';
                              tempSort = 'Newest';
                            }),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Frequency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 10),
                      chipRow<String>(
                        items: _frequencies,
                        label: (f) => f,
                        isSelected: (f) => tempFrequency == f,
                        onSelect: (f) => tempFrequency = f,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sort By',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 10),
                      chipRow<String>(
                        items: _sortOptions,
                        label: (s) => s,
                        isSelected: (s) => tempSort == s,
                        onSelect: (s) => tempSort = s,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedFrequency = tempFrequency;
                              _selectedSort = tempSort;
                            });
                            Navigator.pop(sheetCtx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.buttonColor(ctx),
                            foregroundColor: AppTheme.buttonTextColor(ctx),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.buttonRadius),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Show Equbs',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyEqubsTab(BuildContext context) {
    return Consumer2<PoolProvider, AuthProvider>(
      builder: (context, pool, auth, _) {
        final wallet = auth.walletAddress?.toLowerCase() ?? '';
        final desktop = AppTheme.isDesktop(context);
        final myPools = pool.pools.where((p) {
          final membersList = p['members'] as List? ?? [];
          final memberAddresses = membersList.map((e) {
            if (e is Map) {
              return (e['walletAddress'] ?? '').toString().toLowerCase();
            }
            return e.toString().toLowerCase();
          }).toList();
          final createdBy =
              (p['createdBy'] ?? p['creator'] ?? '').toString().toLowerCase();
          final treasury = (p['treasury'] ?? '').toString().toLowerCase();
          return memberAddresses.contains(wallet) ||
              createdBy == wallet ||
              treasury == wallet;
        }).toList();

        if (pool.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (myPools.isEmpty) {
          return _buildEmpty(context, 'You haven\'t joined any equbs yet');
        }

        return RefreshIndicator(
          onRefresh: () => pool.loadPools(),
          child: desktop
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1280 ? 2 : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppTheme.desktopPanelGap,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 262,
                      ),
                      itemCount: myPools.length,
                      itemBuilder: (_, i) =>
                          _buildMyEqubCard(context, myPools[i]),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: myPools.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildMyEqubCard(context, myPools[i]),
                ),
        );
      },
    );
  }

  static const _categoryToEqubType = {
    'Finance': 0,
    'House': 1,
    'Car': 2,
    'Travel': 3,
    'Special': 4,
    'Workplace': 5,
    'Education': 6,
    'Wedding': 7,
    'Emergency': 8,
  };
  static const _frequencyToCode = {
    'Daily': 0,
    'Weekly': 1,
    'Monthly': 3,
  };

  List<Map<String, dynamic>> _filterPools(List<Map<String, dynamic>> pools) {
    var result = List<Map<String, dynamic>>.from(pools);
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      result = result.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final createdBy =
            (p['createdBy'] ?? p['creator'] ?? '').toString().toLowerCase();
        final onChainId = p['onChainPoolId']?.toString() ?? '';
        return name.contains(query) ||
            createdBy.contains(query) ||
            onChainId.contains(query);
      }).toList();
    }
    if (_selectedCategory != 'All') {
      final typeCode = _categoryToEqubType[_selectedCategory];
      if (typeCode != null) {
        result = result.where((p) => p['equbType'] == typeCode).toList();
      }
    }
    if (_selectedFrequency != 'All') {
      final freqCode = _frequencyToCode[_selectedFrequency];
      if (freqCode != null) {
        result = result.where((p) => p['frequency'] == freqCode).toList();
      }
    }
    result.sort(_comparePools);
    return result;
  }

  int _comparePools(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (_selectedSort) {
      case 'Most Members':
        return _memberCountOf(b).compareTo(_memberCountOf(a));
      case 'Highest Completion':
        return _completionOf(b).compareTo(_completionOf(a));
      case 'Contribution Amount':
        return _contributionValueOf(b).compareTo(_contributionValueOf(a));
      case 'Health Score':
        return _healthScoreOf(b).compareTo(_healthScoreOf(a));
      case 'Newest':
      default:
        return _recencyScoreOf(b).compareTo(_recencyScoreOf(a));
    }
  }

  int _memberCountOf(Map<String, dynamic> pool) =>
      ((pool['members'] as List?) ?? const []).length;

  double _completionOf(Map<String, dynamic> pool) {
    final maxMembers = (pool['maxMembers'] as num?)?.toDouble() ?? 0;
    final currentRound = (pool['currentRound'] as num?)?.toDouble() ?? 0;
    if (maxMembers <= 0) {
      return 0;
    }
    return currentRound / maxMembers;
  }

  double _contributionValueOf(Map<String, dynamic> pool) {
    final raw = pool['contributionAmount'];
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  double _healthScoreOf(Map<String, dynamic> pool) {
    final memberCount = _memberCountOf(pool).toDouble();
    final maxMembers = (pool['maxMembers'] as num?)?.toDouble() ?? 0;
    final fillRate = maxMembers > 0 ? memberCount / maxMembers : 0;
    final completion = _completionOf(pool);
    final status = pool['status']?.toString() ?? 'pending';
    final statusBoost = status == 'active'
        ? 0.2
        : status == 'completed'
            ? 0.1
            : 0.0;
    return (completion * 0.5) + (fillRate * 0.3) + statusBoost;
  }

  double _recencyScoreOf(Map<String, dynamic> pool) {
    for (final key in ['createdAt', 'created_at', 'updatedAt', 'updated_at']) {
      final value = pool[key];
      if (value is num) {
        return value.toDouble();
      }
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed.millisecondsSinceEpoch.toDouble();
      }
    }

    final onChainId = pool['onChainPoolId'];
    if (onChainId is num) {
      return onChainId.toDouble();
    }

    final idValue = double.tryParse(pool['id']?.toString() ?? '');
    return idValue ?? 0;
  }

  Widget _buildCategoryChips({double horizontalPadding = 20}) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.buttonColor(context)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.textHintColor(context)),
              ),
              child: Text(cat,
                  style: TextStyle(
                      fontSize: 12,
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

  Widget _buildDesktopBrowseStatusCard(
    BuildContext context, {
    required String title,
    required String value,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.textHintColor(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static const _equbTypeLabels = {
    0: 'Finance',
    1: 'House',
    2: 'Car',
    3: 'Travel',
    4: 'Special',
    5: 'Workplace',
    6: 'Education',
    7: 'Wedding',
    8: 'Emergency'
  };
  static const _frequencyLabels = {
    0: 'Daily',
    1: 'Weekly',
    2: 'BiWeekly',
    3: 'Monthly'
  };
  static const _equbTypeIcons = <int, IconData>{
    0: Icons.account_balance_wallet_outlined,
    1: Icons.home_outlined,
    2: Icons.directions_car_outlined,
    3: Icons.flight_outlined,
    4: Icons.star_outline_rounded,
    5: Icons.work_outline_rounded,
    6: Icons.school_outlined,
    7: Icons.favorite_outline_rounded,
    8: Icons.local_hospital_outlined,
  };

  Widget _buildMemberAvatarStack(
      BuildContext context, List members, int maxMembers) {
    final count = members.length;
    final show = count > 3 ? 3 : count;
    final colors = [
      AppTheme.accentYellow,
      AppTheme.positive,
      AppTheme.secondaryColor,
      AppTheme.primaryColor
    ];
    return SizedBox(
      width: show * 22.0 + (count > 3 ? 22 : 0),
      height: 28,
      child: Stack(
        children: [
          for (int i = 0; i < show; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i % colors.length].withValues(alpha: 0.25),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 2),
                ),
                child: Icon(Icons.person,
                    size: 14, color: colors[i % colors.length]),
              ),
            ),
          if (count > 3)
            Positioned(
              left: show * 18.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.textHintColor(context).withValues(alpha: 0.3),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 2),
                ),
                child: Center(
                  child: Text('+${count - 3}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondaryColor(context))),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEqubCard(BuildContext context, Map<String, dynamic> pool) {
    final onChainId = pool['onChainPoolId'];
    final poolId = pool['id']?.toString() ?? '';
    final name = pool['name']?.toString() ??
        (onChainId != null
            ? 'Equb #$onChainId'
            : 'Equb ${poolId.length >= 6 ? poolId.substring(0, 6) : poolId}');
    final equbType = pool['equbType'] as int?;
    final type = _equbTypeLabels[equbType] ?? 'Finance';
    final freq = pool['frequency'];
    final frequency =
        freq is int ? (_frequencyLabels[freq] ?? 'Monthly') : 'Monthly';
    final rawContribution = pool['contributionAmount']?.toString() ?? '0';
    final contribution = _formatContribution(rawContribution);
    final membersList = (pool['members'] as List?) ?? [];
    final members = membersList.length;
    final maxMembers = (pool['maxMembers'] as num?)?.toInt() ?? 0;
    final currentRound = (pool['currentRound'] as num?)?.toInt() ?? 0;
    final status = pool['status']?.toString() ?? 'pending';
    final isActive = status == 'active';
    final isCompleted = status == 'completed';
    final progress =
        maxMembers > 0 ? (currentRound / maxMembers).clamp(0.0, 1.0) : 0.0;
    final typeColor = _typeColor(type, context);
    final typeIcon = _equbTypeIcons[equbType] ?? Icons.groups_rounded;

    return GestureDetector(
      onTap: () => context.push('/pools/$poolId'),
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Icon(typeIcon, size: 26, color: typeColor)),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppTheme.positive
                                : isCompleted
                                    ? AppTheme.accentYellow
                                    : AppTheme.textHintColor(context),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.textHintColor(context)),
                            ),
                            child: Text(frequency,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppTheme.textSecondaryColor(context))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Contribution: $contribution',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMemberAvatarStack(context, membersList, maxMembers),
                const Spacer(),
                Text(
                  contribution,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentYellow,
                      letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cycle $currentRound of $maxMembers',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context))),
                Text('$members/$maxMembers members',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context))),
              ],
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildMyEqubCard(BuildContext context, Map<String, dynamic> pool) {
    final onChainId = pool['onChainPoolId'];
    final poolId = pool['id']?.toString() ?? '';
    final name = pool['name']?.toString() ??
        (onChainId != null
            ? 'Equb #$onChainId'
            : 'Equb ${poolId.length >= 6 ? poolId.substring(0, 6) : poolId}');
    final equbType = pool['equbType'] as int?;
    final type = _equbTypeLabels[equbType] ?? 'Finance';
    final freq = pool['frequency'];
    final frequency =
        freq is int ? (_frequencyLabels[freq] ?? 'Monthly') : 'Monthly';
    final currentRound = (pool['currentRound'] as num?)?.toInt() ?? 0;
    final maxMembers = (pool['maxMembers'] as num?)?.toInt() ?? 1;
    final membersList = (pool['members'] as List?) ?? [];
    final members = membersList.length;
    final progress =
        maxMembers > 0 ? (currentRound / maxMembers).clamp(0.0, 1.0) : 0.0;
    final status = pool['status']?.toString() ?? 'pending';
    final rawContribution = pool['contributionAmount']?.toString() ?? '0';
    final contribution = _formatContribution(rawContribution);
    final isActive = status == 'active';
    final isCompleted = status == 'completed';
    final typeColor = _typeColor(type, context);
    final typeIcon = _equbTypeIcons[equbType] ?? Icons.groups_rounded;

    return GestureDetector(
      onTap: () => context.push('/pools/$poolId'),
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Icon(typeIcon, size: 26, color: typeColor)),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppTheme.positive
                                : isCompleted
                                    ? AppTheme.accentYellow
                                    : AppTheme.textHintColor(context),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.textHintColor(context)),
                            ),
                            child: Text(frequency,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppTheme.textSecondaryColor(context))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Contribution: $contribution',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMemberAvatarStack(context, membersList, maxMembers),
                const Spacer(),
                Text(
                  contribution,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentYellow,
                      letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cycle $currentRound of $maxMembers',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context))),
                Text('$members/$maxMembers members',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context))),
              ],
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }

  String _formatContribution(String raw) {
    final sym = context.read<NetworkProvider>().nativeSymbol;
    final wei = BigInt.tryParse(raw);
    if (wei != null && !raw.contains('.') && wei > BigInt.from(1e15)) {
      final eth = wei / BigInt.from(10).pow(18);
      final remainder = wei % BigInt.from(10).pow(18);
      final decimals = (remainder / BigInt.from(10).pow(14)).toInt();
      if (decimals == 0) return '${eth.toString()} $sym';
      return '${eth.toString()}.${decimals.toString().padLeft(4, '0').replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    final n = double.tryParse(raw);
    if (n == null) return raw;
    if (n == n.truncateToDouble()) return '${n.toInt()} $sym';
    if (n < 0.01) {
      return '${n.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    if (n < 1) {
      return '${n.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '')} $sym';
    }
    return '${n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} $sym';
  }

  Widget _buildEmpty(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded,
              size: 48, color: AppTheme.textTertiaryColor(context)),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEmptyWithRefresh(BuildContext context, PoolProvider pool) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded,
              size: 48, color: AppTheme.textTertiaryColor(context)),
          const SizedBox(height: 12),
          Text('No equbs found', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: pool.isLoading ? null : () => pool.loadPools(),
            icon: pool.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(pool.isLoading ? 'Loading...' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, PoolProvider pool) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.dangerColor),
            const SizedBox(height: 12),
            Text(pool.errorMessage ?? 'Failed to load equbs',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: pool.isLoading ? null : () => pool.loadPools(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor(context),
                foregroundColor: AppTheme.buttonTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type, BuildContext context) {
    return switch (type.toLowerCase()) {
      'finance' => AppTheme.positive,
      'house' => AppTheme.secondaryColor,
      'car' => AppTheme.accentYellowDark,
      'travel' => AppTheme.primaryColor,
      'special' => AppTheme.highlightRed,
      'workplace' => AppTheme.primaryColor.withValues(alpha: 0.85),
      'education' => AppTheme.secondaryColor.withValues(alpha: 0.82),
      'wedding' => AppTheme.accentYellow,
      'emergency' => AppTheme.negative,
      _ => AppTheme.textSecondaryColor(context),
    };
  }

  void _showCreateDialog(BuildContext ctx) async {
    final result = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateEqubSheet(),
    );
    if (!mounted) return;
    await context.read<PoolProvider>().loadPools();
    if (mounted && result == true) {
      _tabController.animateTo(0);
    }
  }
}

class _CreateEqubSheet extends StatefulWidget {
  const _CreateEqubSheet();

  @override
  State<_CreateEqubSheet> createState() => _CreateEqubSheetState();
}

class _CreateEqubSheetState extends State<_CreateEqubSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contributionCtrl = TextEditingController(text: '0.01');
  final _maxMembersCtrl = TextEditingController(text: '5');
  int _selectedTier = 1;
  bool _isSubmitting = false;

  static const _tiers = [
    (value: 1, label: 'Bronze', desc: 'Low stakes, casual'),
    (value: 2, label: 'Silver', desc: 'Medium stakes'),
    (value: 3, label: 'Gold', desc: 'High stakes, serious'),
  ];

  @override
  void dispose() {
    _contributionCtrl.dispose();
    _maxMembersCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final pool = context.read<PoolProvider>();
    final walletService = context.read<WalletService>();

    debugPrint(
        '[CreateEqub] isConnected=${walletService.isConnected}, walletAddr=${walletService.walletAddress}, authAddr=${auth.walletAddress}');

    // Ensure wallet is connected for signing
    if (!walletService.isConnected) {
      setState(() => _isSubmitting = true);
      debugPrint('[CreateEqub] Connecting wallet...');
      final addr = await walletService.connect();
      if (!mounted) return;
      debugPrint(
          '[CreateEqub] Connect result: $addr, error: ${walletService.errorMessage}');
      if (addr == null) {
        setState(() => _isSubmitting = false);
        _showSnack(
            walletService.errorMessage ?? 'Connect your wallet to sign.');
        return;
      }
    }

    final treasury = walletService.walletAddress ?? auth.walletAddress;
    if (treasury == null || treasury.isEmpty) {
      _showSnack('Connect your wallet first');
      return;
    }

    setState(() => _isSubmitting = true);

    final ethValue = double.parse(_contributionCtrl.text.trim());
    final weiBig = BigInt.from(ethValue * 1e18);
    final weiString = weiBig.toString();

    debugPrint(
        '[CreateEqub] Building TX: tier=$_selectedTier, amount=$weiString, treasury=$treasury');

    final txHash = await pool.buildAndSignCreatePool(
      tier: _selectedTier,
      contributionAmount: weiString,
      maxMembers: int.parse(_maxMembersCtrl.text.trim()),
      treasury: treasury,
      token: null,
    );

    debugPrint(
        '[CreateEqub] Result: txHash=$txHash, error=${pool.errorMessage}');

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (txHash != null) {
      if (mounted) Navigator.pop(context, true);
      _showSnack('Equb created successfully!');
    } else {
      _showSnack(pool.errorMessage ?? 'Failed to create equb');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Form(
          key: _formKey,
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
              const SizedBox(height: 20),
              Text(
                'Create New Equb',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              _buildTierSelector(),
              const SizedBox(height: 20),
              _buildField(
                label:
                    'Contribution Amount (${context.read<NetworkProvider>().nativeSymbol})',
                controller: _contributionCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                label: 'Max Members',
                controller: _maxMembersCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 2) return 'At least 2 members';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.buttonColor(context),
                    foregroundColor: AppTheme.buttonTextColor(context),
                    disabledBackgroundColor:
                        AppTheme.textHintColor(context).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Create Equb',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tier',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _tiers.map((t) {
            final selected = _selectedTier == t.value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTier = t.value),
                child: Container(
                  margin: EdgeInsets.only(
                    right: t.value < 3 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.buttonColor(context)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? null
                        : Border.all(color: AppTheme.textHintColor(context)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected
                              ? AppTheme.buttonTextColor(context)
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.desc,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? AppTheme.buttonTextColor(context)
                                  .withValues(alpha: 0.7)
                              : AppTheme.textTertiaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppTheme.textPrimaryColor(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondaryColor(context)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.textHintColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.accentYellowDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.negative, width: 2),
        ),
      ),
    );
  }
}
