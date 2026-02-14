import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class TransactionsScreen extends StatefulWidget {
  /// When true, renders as a full page with its own Scaffold+gradient.
  /// When false, renders just the body content (for embedding in MainShell).
  final bool standalone;

  const TransactionsScreen({super.key, this.standalone = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTransactions();
      });
    }
  }

  void _loadTransactions() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      wallet.loadTransactions(auth.walletAddress!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.standalone) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
                icon: const Icon(Icons.search_rounded, size: 24),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: body,
        ),
      );
    }

    // Embedded mode: header row + body
    return Column(
      children: [
        // Inline header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 24),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        final txList = wallet.transactions;

        if (wallet.isLoading && txList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (txList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your token transfers will appear here once your wallet is funded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group transactions - for now show all in a single group
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Card selector chip
            _buildCardChip(),
            const SizedBox(height: 24),
            _buildGroupHeader('Recent'),
            const SizedBox(height: 12),
            _buildGroupCard(txList),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildCardChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkButton,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mastercard-style circles
            SizedBox(
              width: 28,
              height: 18,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEB001B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF79E1B).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '••••2872',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return _buildTransactionItem(item, isLast);
        }),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> item, bool isLast) {
    final type = item['type']?.toString() ?? 'received';
    final isSent = type == 'sent';
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    final amountStr = isSent
        ? '-\$${amount.toStringAsFixed(2)}'
        : '+\$${amount.toStringAsFixed(2)}';

    // Shorten addresses
    final from = item['from']?.toString() ?? '';
    final to = item['to']?.toString() ?? '';
    final displayAddr = isSent ? to : from;
    final name = displayAddr.length > 10
        ? '${displayAddr.substring(0, 6)}...${displayAddr.substring(displayAddr.length - 4)}'
        : displayAddr;
    final tokenSymbol = item['token']?.toString() ?? 'USDC';

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
          // Avatar
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
          // Name + type
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$tokenSymbol ${isSent ? "Sent" : "Received"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppTheme.textTertiary),
                  ],
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
              color: isSent ? AppTheme.negative : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}
