import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/network_provider.dart';
import '../providers/wallet_provider.dart';

class TransactionsScreen extends StatefulWidget {
  final bool standalone;

  const TransactionsScreen({super.key, this.standalone = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const _storage = FlutterSecureStorage();
  static const int _pageSize = 50;
  String? _lastLoadedWallet;
  int _currentLimit = _pageSize;
  bool _loadingOlder = false;

  String _rangePreset = '2D';
  String _tokenFilter = 'All';
  String _directionFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (auth.walletAddress != null &&
        _lastLoadedWallet != auth.walletAddress &&
        mounted) {
      _lastLoadedWallet = auth.walletAddress;
      _currentLimit = _pageSize;
      _loadingOlder = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreFiltersAndLoad();
      });
    } else if (auth.walletAddress == null) {
      _lastLoadedWallet = null;
    }
  }

  String? get _walletAddress => context.read<AuthProvider>().walletAddress;

  String? get _filtersStorageKey {
    final wallet = _walletAddress;
    if (wallet == null || wallet.isEmpty) return null;
    return 'tx_filters:${wallet.toLowerCase()}';
  }

  Future<void> _restoreFiltersAndLoad() async {
    if (!mounted) return;

    await _restoreFilters();
    if (!mounted) return;

    await _loadTransactions();
  }

  Future<void> _restoreFilters() async {
    final key = _filtersStorageKey;
    if (key == null) return;

    final raw = await _storage.read(key: key);
    if (!mounted) return;

    if (raw == null || raw.isEmpty) {
      setState(() {
        _rangePreset = '2D';
        _tokenFilter = 'All';
        _directionFilter = 'All';
        _statusFilter = 'All';
        _customFrom = null;
        _customTo = null;
      });
      return;
    }

    final parts = raw.split('|');
    final rangePreset = parts.isNotEmpty ? parts[0] : '2D';
    final token = parts.length > 1 ? parts[1] : 'All';
    final direction = parts.length > 2 ? parts[2] : 'All';
    final status = parts.length > 3 ? parts[3] : 'All';
    final customFromRaw = parts.length > 4 ? parts[4] : '';
    final customToRaw = parts.length > 5 ? parts[5] : '';

    DateTime? parseDate(String value) {
      if (value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    setState(() {
      _rangePreset = _validRange(rangePreset) ? rangePreset : '2D';
      _tokenFilter = _validToken(token) ? token : 'All';
      _directionFilter = _validDirection(direction) ? direction : 'All';
      _statusFilter = _validStatus(status) ? status : 'All';
      _customFrom = parseDate(customFromRaw);
      _customTo = parseDate(customToRaw);
    });
  }

  Future<void> _saveFilters() async {
    final key = _filtersStorageKey;
    if (key == null) return;

    final encoded = [
      _rangePreset,
      _tokenFilter,
      _directionFilter,
      _statusFilter,
      _customFrom?.toIso8601String() ?? '',
      _customTo?.toIso8601String() ?? '',
    ].join('|');

    await _storage.write(key: key, value: encoded);
  }

  bool _validRange(String v) =>
      const {'2D', '7D', '30D', 'All', 'Custom'}.contains(v);
  bool _validToken(String v) => const {'All', 'USDC', 'USDT', 'CTC', 'tCTC'}.contains(v);
  bool _validDirection(String v) =>
      const {'All', 'Sent', 'Received'}.contains(v);
  bool _validStatus(String v) => const {'All', 'Success', 'Failed'}.contains(v);

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      int? fromTimestamp;
      int? toTimestamp;
      final now = DateTime.now();
      switch (_rangePreset) {
        case '2D':
          fromTimestamp = now
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch;
          toTimestamp = now.millisecondsSinceEpoch;
          break;
        case '7D':
          fromTimestamp = now
              .subtract(const Duration(days: 7))
              .millisecondsSinceEpoch;
          toTimestamp = now.millisecondsSinceEpoch;
          break;
        case '30D':
          fromTimestamp = now
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch;
          toTimestamp = now.millisecondsSinceEpoch;
          break;
        case 'Custom':
          fromTimestamp = _customFrom?.millisecondsSinceEpoch;
          toTimestamp = _customTo?.millisecondsSinceEpoch;
          break;
        case 'All':
        default:
          break;
      }

      final direction = _directionFilter == 'All'
          ? null
          : _directionFilter.toLowerCase();
      final status = _statusFilter == 'All' ? null : _statusFilter.toLowerCase();

      await wallet.loadTransactions(
        auth.walletAddress!,
        token: _tokenFilter == 'All' ? 'ALL' : _tokenFilter,
        limit: _currentLimit,
        fromTimestamp: fromTimestamp,
        toTimestamp: toTimestamp,
        direction: direction,
        status: status,
      );
    }
  }

  void _resetPagination() {
    _currentLimit = _pageSize;
    _loadingOlder = false;
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;

    setState(() {
      _loadingOlder = true;
      _currentLimit += _pageSize;
    });

    try {
      await _loadTransactions();
    } finally {
      if (mounted) {
        setState(() {
          _loadingOlder = false;
        });
      }
    }
  }

  Future<void> _setRangePreset(String preset) async {
    if (!mounted) return;
    if (_rangePreset == preset && preset != 'Custom') return;

    if (preset == 'Custom') {
      final now = DateTime.now();
      final initialStart = _customFrom ?? now.subtract(const Duration(days: 2));
      final initialEnd = _customTo ?? now;
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      );
      if (picked == null || !mounted) return;

      setState(() {
        _rangePreset = 'Custom';
        _customFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _customTo = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
        _resetPagination();
      });
      await _saveFilters();
      await _loadTransactions();
      return;
    }

    setState(() {
      _rangePreset = preset;
      _resetPagination();
    });
    await _saveFilters();
    await _loadTransactions();
  }

  Future<void> _setTokenFilter(String value) async {
    if (_tokenFilter == value) return;
    setState(() {
      _tokenFilter = value;
      _resetPagination();
    });
    await _saveFilters();
    await _loadTransactions();
  }

  Future<void> _setDirectionFilter(String value) async {
    if (_directionFilter == value) return;
    setState(() {
      _directionFilter = value;
      _resetPagination();
    });
    await _saveFilters();
    await _loadTransactions();
  }

  Future<void> _setStatusFilter(String value) async {
    if (_statusFilter == value) return;
    setState(() {
      _statusFilter = value;
      _resetPagination();
    });
    await _saveFilters();
    await _loadTransactions();
  }

  bool get _hasActiveFilters {
    if (_rangePreset != '2D') return true;
    if (_tokenFilter != 'All') return true;
    if (_directionFilter != 'All') return true;
    if (_statusFilter != 'All') return true;
    if (_customFrom != null || _customTo != null) return true;
    return false;
  }

  Future<void> _clearFiltersToDefault() async {
    setState(() {
      _rangePreset = '2D';
      _tokenFilter = 'All';
      _directionFilter = 'All';
      _statusFilter = 'All';
      _customFrom = null;
      _customTo = null;
      _resetPagination();
    });
    await _saveFilters();
    await _loadTransactions();
  }

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> source) {
    final now = DateTime.now();
    DateTime? rangeStart;
    DateTime? rangeEnd;

    switch (_rangePreset) {
      case '2D':
        rangeStart = now.subtract(const Duration(days: 2));
        rangeEnd = now;
        break;
      case '7D':
        rangeStart = now.subtract(const Duration(days: 7));
        rangeEnd = now;
        break;
      case '30D':
        rangeStart = now.subtract(const Duration(days: 30));
        rangeEnd = now;
        break;
      case 'Custom':
        rangeStart = _customFrom;
        rangeEnd = _customTo;
        break;
      case 'All':
      default:
        break;
    }

    bool matches(Map<String, dynamic> tx) {
      final token = (tx['token']?.toString().toUpperCase() ?? 'USDC');
      final type = (tx['type']?.toString().toLowerCase() ?? 'received');
      final isFailed = tx['isError'] == true || tx['isError']?.toString() == '1';

      final ts = tx['timestamp'];
      DateTime? txDate;
      if (ts is num && ts.toInt() > 0) {
        txDate = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      }

      if (_tokenFilter != 'All' && token != _tokenFilter) return false;

      if (_directionFilter == 'Sent' && type != 'sent') return false;
      if (_directionFilter == 'Received' && type != 'received') return false;

      if (_statusFilter == 'Failed' && !isFailed) return false;
      if (_statusFilter == 'Success' && isFailed) return false;

      if (rangeStart != null && rangeEnd != null) {
        if (txDate == null) return false;
        if (txDate.isBefore(rangeStart) || txDate.isAfter(rangeEnd)) {
          return false;
        }
      }

      return true;
    }

    final filtered = source.where(matches).toList();
    filtered.sort((a, b) {
      final bBlock = (b['blockNumber'] as num?) ?? 0;
      final aBlock = (a['blockNumber'] as num?) ?? 0;
      return bBlock.compareTo(aBlock);
    });
    return filtered;
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          _buildChoiceChip(
            context,
            label: _rangePreset,
            onPressed: () async {
              final selected = await _showChoiceSheet(
                title: 'Time Range',
                options: const ['2D', '7D', '30D', 'All', 'Custom'],
                selected: _rangePreset,
              );
              if (selected != null) await _setRangePreset(selected);
            },
          ),
          const SizedBox(width: 8),
          _buildChoiceChip(
            context,
            label: _tokenFilter,
            onPressed: () async {
              final selected = await _showChoiceSheet(
                title: 'Token',
                options: ['All', 'USDC', 'USDT', context.read<NetworkProvider>().nativeSymbol],
                selected: _tokenFilter,
              );
              if (selected != null) await _setTokenFilter(selected);
            },
          ),
          const SizedBox(width: 8),
          _buildChoiceChip(
            context,
            label: _directionFilter,
            onPressed: () async {
              final selected = await _showChoiceSheet(
                title: 'Direction',
                options: const ['All', 'Sent', 'Received'],
                selected: _directionFilter,
              );
              if (selected != null) await _setDirectionFilter(selected);
            },
          ),
          const SizedBox(width: 8),
          _buildChoiceChip(
            context,
            label: _statusFilter,
            onPressed: () async {
              final selected = await _showChoiceSheet(
                title: 'Status',
                options: const ['All', 'Success', 'Failed'],
                selected: _statusFilter,
              );
              if (selected != null) await _setStatusFilter(selected);
            },
          ),
          if (_rangePreset == 'Custom' && _customFrom != null && _customTo != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${DateFormat('MMM d').format(_customFrom!)} - ${DateFormat('MMM d').format(_customTo!)}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(BuildContext context, {required String label, required VoidCallback onPressed}) {
    return ActionChip(
      onPressed: onPressed,
      backgroundColor: AppTheme.cardColor(context),
      side: BorderSide(color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.35)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 16, color: AppTheme.textSecondaryColor(context)),
        ],
      ),
    );
  }

  Future<String?> _showChoiceSheet({
    required String title,
    required List<String> options,
    required String selected,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(option),
                  trailing: option == selected
                      ? const Icon(Icons.check_rounded, color: AppTheme.primaryColor)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.standalone) {
      return Container(
        decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Transactions'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 24),
                onPressed: _loadTransactions,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              _buildFilterChips(context),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 24),
                onPressed: _loadTransactions,
              ),
            ],
          ),
        ),
        _buildFilterChips(context),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer2<AuthProvider, WalletProvider>(
      builder: (context, auth, wallet, _) {
        if (auth.walletAddress == null) {
          return _buildStateCard(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Connect wallet to view transactions',
            subtitle: 'Your transfer history appears after wallet binding.',
          );
        }

        final txList = wallet.transactions;
        final filteredTxList = _applyFilters(txList);
        final canLoadOlder =
            txList.length >= _currentLimit && !_loadingOlder && !wallet.isLoading;

        // When we have a wallet and empty list and not loading, trigger load once
        if (auth.walletAddress != null &&
            txList.isEmpty &&
            !wallet.isLoading &&
            _lastLoadedWallet != auth.walletAddress) {
          _lastLoadedWallet = auth.walletAddress;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadTransactions();
          });
        }

        if (wallet.isLoading && txList.isEmpty) {
          return _buildStateCard(
            context,
            icon: Icons.history_toggle_off_rounded,
            title: 'Loading transactions…',
            subtitle: 'Fetching your latest activity for the selected filters.',
            action: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          );
        }

        if (wallet.errorMessage != null && txList.isEmpty) {
          return _buildStateCard(
            context,
            icon: Icons.error_outline_rounded,
            title: wallet.errorMessage!,
            subtitle: 'Could not fetch transactions. Please retry.',
            action: TextButton.icon(
              onPressed: _loadTransactions,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          );
        }

        if (filteredTxList.isEmpty) {
          if (txList.isEmpty) {
            return _buildStateCard(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'No transactions yet',
              subtitle: 'Your token transfers will appear here once your wallet is funded.',
            );
          }

          return _buildStateCard(
            context,
            icon: Icons.filter_alt_off_rounded,
            title: 'No transactions for current filters',
            subtitle: 'Adjust filters or reset to default 2D view.',
            action: _hasActiveFilters
                ? TextButton.icon(
                    onPressed: _clearFiltersToDefault,
                    icon: const Icon(Icons.restart_alt_rounded, size: 20),
                    label: const Text('Reset filters'),
                  )
                : null,
          );
        }

        final grouped = _groupByDay(filteredTxList);

        return RefreshIndicator(
          onRefresh: () async => _loadTransactions(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (wallet.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              for (var index = 0; index < grouped.length; index++) ...[
                if (index > 0) const SizedBox(height: 24),
                _buildGroupHeader(context, grouped[index].label),
                const SizedBox(height: 12),
                _buildGroupCard(context, grouped[index].transactions),
              ],
              if (wallet.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: _loadTransactions,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(wallet.errorMessage!),
                  ),
                ),
              if (canLoadOlder)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadOlder,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Load older'),
                    ),
                  ),
                ),
              if (_loadingOlder)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_DayGroup> _groupByDay(List<Map<String, dynamic>> txList) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, DateTime> groupDates = {};
    const olderKey = '_older_';

    for (final tx in txList) {
      final timestamp = tx['timestamp'];
      DateTime? txDate;
      if (timestamp != null && timestamp is num) {
        final ms = timestamp.toInt();
        if (ms > 0) {
          txDate = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
      final dayKey = txDate != null
          ? '${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}'
          : olderKey;
      grouped.putIfAbsent(dayKey, () => []);
      grouped[dayKey]!.add({...tx, '_parsedDate': txDate});
      if (txDate != null) {
        groupDates.putIfAbsent(
            dayKey, () => DateTime(txDate!.year, txDate.month, txDate.day));
      } else {
        groupDates.putIfAbsent(dayKey, () => DateTime(1970, 1, 1));
      }
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == olderKey) return 1;
        if (b == olderKey) return -1;
        return b.compareTo(a);
      });

    return sortedKeys.map((key) {
      final date = groupDates[key]!;
      String label;
      if (key == olderKey) {
        label = 'Older';
      } else if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMM d, yyyy').format(date);
      }
      return _DayGroup(label: label, transactions: grouped[key]!);
    }).toList();
  }

  Widget _buildGroupHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiaryColor(context),
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return _buildTransactionItem(context, item, isLast);
        }),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Map<String, dynamic> item, bool isLast) {
    final type = item['type']?.toString() ?? 'received';
    final isSent = type == 'sent';
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    final tokenSymbol = item['token']?.toString() ?? 'USDC';
    final nativeSym = context.read<NetworkProvider>().nativeSymbol;
    final isNative = tokenSymbol == 'CTC' || tokenSymbol == 'tCTC';
    final isFailed = item['isError'] == true;
    final amountStr = isNative
        ? '${isSent ? '-' : '+'}${amount.toStringAsFixed(4)} $nativeSym'
        : '${isSent ? '-\$' : '+\$'}${amount.toStringAsFixed(2)}';

    final from = item['from']?.toString() ?? '';
    final to = item['to']?.toString() ?? '';
    final displayAddr = isSent ? to : from;
    final name = displayAddr.length > 10
        ? '${displayAddr.substring(0, 6)}...${displayAddr.substring(displayAddr.length - 4)}'
        : displayAddr;

    // Format time (show block number when timestamp missing)
    final parsedDate = item['_parsedDate'] as DateTime?;
    final blockNumber = item['blockNumber'];
    final timeStr = parsedDate != null
        ? DateFormat('h:mm a').format(parsedDate)
        : (blockNumber != null ? 'Block #$blockNumber' : '—');

    Color color = isSent ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    if (isFailed) color = AppTheme.textTertiaryColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE4F0E0), width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSent ? Icons.north_east_rounded : Icons.south_west_rounded,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      isFailed
                          ? 'Failed'
                          : '$tokenSymbol ${isSent ? "Sent" : "Received"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            amountStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isSent ? AppTheme.negative : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroup {
  final String label;
  final List<Map<String, dynamic>> transactions;

  _DayGroup({required this.label, required this.transactions});
}
