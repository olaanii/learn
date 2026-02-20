import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/notification_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _balanceVisible = true;
  String? _lastLoadedWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
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
  }

  void _loadWalletData() {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      wallet.loadAll(auth.walletAddress!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, AuthProvider>(
      builder: (context, wallet, auth, _) {
        // When wallet is available and transactions empty and not loading, trigger load
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
        return RefreshIndicator(
          onRefresh: () async {
            if (auth.walletAddress != null) {
              await wallet.loadAll(auth.walletAddress!);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, auth),
                const SizedBox(height: 24),
                // White card wrapping balance + quick actions
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _buildBalanceCard(context, wallet),
                      _buildTokenSelector(context, wallet, auth),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: _buildQuickActions(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildTransactionsSection(context, wallet),
                const SizedBox(height: 28),
                _buildCurrencySection(context, wallet),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header: avatar + greeting + icons ──────────────────────────────
  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    // Derive display name from wallet or identity
    final name = auth.walletAddress != null
        ? '${auth.walletAddress!.substring(0, 6)}...'
        : 'User';

    return Row(
      children: [
        // Avatar – tap to open Profile
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.textTertiary.withValues(alpha: 0.3),
              border: Border.all(color: AppTheme.cardWhite, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              'https://i.pravatar.cc/150?img=12',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person,
                size: 22,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Hi, $name!',
            style: Theme.of(context).textTheme.headlineLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!AppConfig.isMainnet) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange, width: 0.5),
            ),
            child: const Text(
              'TESTNET',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const Spacer(),
        _buildHeaderIcon(Icons.show_chart_rounded),
        const SizedBox(width: 8),
        _buildNotificationBell(context),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loadWalletData,
          child: _buildHeaderIcon(Icons.sync_rounded),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.cardWhite.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: AppTheme.textPrimary),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHeaderIcon(Icons.notifications_outlined),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.dangerColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Balance card (yellow) ──────────────────────────────────────────
  Widget _buildTokenSelector(BuildContext context, WalletProvider wallet, AuthProvider auth) {
    final tokens = ['USDC', 'USDT'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tokens.map((t) {
          final isSelected = wallet.token == t;
          final bal = wallet.balanceOf(t);
          return Expanded(
            child: GestureDetector(
              onTap: () => wallet.selectToken(t, walletAddress: auth.walletAddress),
              child: Container(
                margin: EdgeInsets.only(
                  right: t == tokens.first ? 6 : 0,
                  left: t == tokens.last ? 6 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentYellow.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentYellow
                        : Colors.grey.withValues(alpha: 0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$$bal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletProvider wallet) {
    // Format balance with commas
    final rawBalance = wallet.balance;
    final balanceNum = double.tryParse(rawBalance) ?? 0.0;
    final balanceFormatted = _formatBalance(balanceNum);

    // Build exchange rate string from provider rates
    String exchangeRate = '1 USD = EUR 0.95= GBR 0.79';
    if (wallet.rates.isNotEmpty) {
      final eurRate = wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95';
      final gbpRate = wallet.rates['GBP']?.toStringAsFixed(2) ?? '0.79';
      exchangeRate = '1 USD = EUR $eurRate= GBR $gbpRate';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Stack(
        children: [
          // Eye icon positioned top-right
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _balanceVisible = !_balanceVisible),
              child: Icon(
                _balanceVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: AppTheme.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ),
          // All content centered
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // Token label – centered
                Text(
                  wallet.token,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 3),
                // Exchange rate – centered
                Text(
                  exchangeRate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 14),
                // Balance amount – centered
                wallet.isLoading
                    ? const SizedBox(
                        height: 42,
                        width: 42,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _balanceVisible ? '\$$balanceFormatted' : '••••••••',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -1.0,
                        ),
                      ),
                const SizedBox(height: 4),
                // Change indicator – centered
                Text(
                  wallet.isLoading ? '' : '+\$0.00',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(double balance) {
    // Add commas to the integer part
    final parts = balance.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    return '$buffer.$decPart';
  }

  // ── Quick action buttons ───────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Pay',
          onTap: () => context.push('/pay'),
        ),
        _buildActionButton(
          icon: Icons.show_chart_rounded,
          label: 'Transfer',
          onTap: () => context.push('/fund-wallet'),
        ),
        _buildActionButton(
          icon: Icons.south_west_rounded,
          label: 'Receive',
          onTap: () => context.push('/receive'),
        ),
        _buildActionButton(
          icon: Icons.groups_rounded,
          label: 'Equb',
          onTap: () => context.push('/pools'),
        ),
        _buildActionButton(
          icon: Icons.shield_outlined,
          label: 'Collateral',
          onTap: () => context.push('/collateral'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 22, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Latest Transactions ────────────────────────────────────────────
  Widget _buildTransactionsSection(BuildContext context, WalletProvider wallet) {
    // Use provider transactions if available, otherwise show empty state
    final txList = wallet.transactions;

    return Column(
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Latest Transactions',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/transactions'),
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Transaction list
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: txList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      wallet.isLoading
                          ? 'Loading transactions...'
                          : 'No transactions yet',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(
                    txList.length > 5 ? 5 : txList.length,
                    (i) {
                      final tx = txList[i];
                      final isLast = i == (txList.length > 5 ? 4 : txList.length - 1);
                      return _buildTransactionTile(tx, isLast);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx, bool isLast) {
    final type = tx['type'] as String? ?? 'received';
    final isSent = type == 'sent';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final tokenSymbol = tx['token']?.toString() ?? 'USDC';
    final isNative = tokenSymbol == 'CTC';
    final isFailed = tx['isError'] == true;
    final amountStr = isNative
        ? '${isSent ? '-' : '+'}${amount.toStringAsFixed(4)} CTC'
        : '${isSent ? r'-$' : r'+$'}${amount.toStringAsFixed(2)}';

    // Shorten addresses for display
    final from = tx['from']?.toString() ?? '';
    final to = tx['to']?.toString() ?? '';
    final displayAddr = isSent ? to : from;
    final name = displayAddr.length > 10
        ? '${displayAddr.substring(0, 6)}...${displayAddr.substring(displayAddr.length - 4)}'
        : displayAddr;

    Color color = isSent ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    if (isFailed) color = AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
      ),
      child: Row(
        children: [
          // Avatar/icon
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
          // Name + token
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tokenSymbol,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Text(
            amountStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isSent ? AppTheme.negative : AppTheme.positive,
            ),
          ),
        ],
      ),
    );
  }

  // ── Currency section ───────────────────────────────────────────────
  Widget _buildCurrencySection(BuildContext context, WalletProvider wallet) {
    final balanceNum = double.tryParse(wallet.balance) ?? 0.0;

    // 3 currencies matching the design: Euro, Pound, Swiss Franc
    final currencyConfig = [
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'color': const Color(0xFF22C55E)},
      {'code': 'GBP', 'symbol': '£', 'name': 'Pound', 'color': const Color(0xFF6366F1)},
      {'code': 'CHF', 'symbol': 'F', 'name': 'Swiss Franc', 'color': const Color(0xFFF59E0B)},
    ];

    // Default fallback rates
    final fallbackRates = {'EUR': 0.95, 'GBP': 0.79, 'CHF': 0.91};

    final currencies = currencyConfig.map((cfg) {
      final code = cfg['code'] as String;
      final rate = wallet.rates[code] ?? fallbackRates[code] ?? 1.0;
      final convertedValue = balanceNum * rate;
      return {
        'symbol': cfg['symbol'],
        'name': cfg['name'],
        'value': _formatBalance(convertedValue),
        'color': cfg['color'],
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (int i = 0; i < currencies.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _buildCurrencyCard(currencies[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (c['color'] as Color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                c['symbol'] as String,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c['color'] as Color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c['name'] as String,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            c['value'] as String,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
