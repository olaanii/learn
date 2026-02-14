import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _balanceVisible = true;
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadWalletData();
      });
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
        const Spacer(),
        _buildHeaderIcon(Icons.show_chart_rounded),
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

  // ── Balance card (yellow) ──────────────────────────────────────────
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
          icon: Icons.add_circle_outline_rounded,
          label: 'Fund',
          onTap: () => context.push('/fund-wallet'),
        ),
        _buildActionButton(
          icon: Icons.south_west_rounded,
          label: 'Receive',
          onTap: () => context.push('/receive'),
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
            Text(
              'Latest Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
    final amountStr = isSent
        ? '-\$${amount.toStringAsFixed(2)}'
        : '+\$${amount.toStringAsFixed(2)}';

    // Shorten addresses for display
    final from = tx['from']?.toString() ?? '';
    final to = tx['to']?.toString() ?? '';
    final displayAddr = isSent ? to : from;
    final name = displayAddr.length > 10
        ? '${displayAddr.substring(0, 6)}...${displayAddr.substring(displayAddr.length - 4)}'
        : displayAddr;

    final tokenSymbol = tx['token']?.toString() ?? 'USDC';
    final color = isSent ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

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
    // Build currency cards from provider rates
    final currencies = <Map<String, dynamic>>[];
    final rateConfig = {
      'EUR': {'symbol': '€', 'name': 'Euro', 'color': const Color(0xFF22C55E)},
      'GBP': {'symbol': '£', 'name': 'British pound', 'color': const Color(0xFF6366F1)},
      'CHF': {'symbol': 'F', 'name': 'Swiss Franc', 'color': const Color(0xFFF59E0B)},
      'ETB': {'symbol': 'Br', 'name': 'Eth. Birr', 'color': const Color(0xFF3B82F6)},
      'KES': {'symbol': 'KSh', 'name': 'Kenya Shill.', 'color': const Color(0xFFEF4444)},
    };

    if (wallet.rates.isNotEmpty) {
      for (final entry in wallet.rates.entries) {
        final config = rateConfig[entry.key];
        if (config != null) {
          currencies.add({
            'symbol': config['symbol'],
            'name': config['name'],
            'rate': entry.value.toStringAsFixed(2),
            'color': config['color'],
          });
        }
      }
    } else {
      // Fallback static data
      currencies.addAll([
        {'symbol': '€', 'name': 'Euro', 'rate': '0.95', 'color': const Color(0xFF22C55E)},
        {'symbol': '£', 'name': 'British pound', 'rate': '0.79', 'color': const Color(0xFF6366F1)},
      ]);
    }

    // Only show first 2 currency cards to leave room for the "Add" card
    final displayCurrencies = currencies.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 112,
          child: Row(
            children: [
              ...displayCurrencies.map((c) {
                return Expanded(child: _buildCurrencyCard(c));
              }),
              const SizedBox(width: 10),
              // Add Currency card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkButton,
                    borderRadius:
                        BorderRadius.circular(AppTheme.cardRadiusSmall),
                    boxShadow: AppTheme.subtleShadow,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 26, color: Colors.white),
                      SizedBox(height: 6),
                      Text(
                        'Add\nCurrency',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 8),
          Text(
            c['name'] as String,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            c['rate'] as String,
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
