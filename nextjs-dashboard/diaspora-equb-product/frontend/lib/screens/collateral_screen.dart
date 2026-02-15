import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/collateral_provider.dart';
import '../providers/wallet_provider.dart';

class CollateralScreen extends StatefulWidget {
  const CollateralScreen({super.key});

  @override
  State<CollateralScreen> createState() => _CollateralScreenState();
}

class _CollateralScreenState extends State<CollateralScreen> {
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final collateral = context.read<CollateralProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      collateral.loadCollateral(auth.walletAddress!);
      wallet.loadAllBalances(auth.walletAddress!);
    }
  }

  Future<void> _lockCollateral() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final collateral = context.read<CollateralProvider>();
    final wallet = context.read<WalletProvider>();

    if (auth.walletAddress == null) return;

    final success = await collateral.lockCollateral(
      walletAddress: auth.walletAddress!,
      amount: amount,
    );

    if (mounted) {
      if (success) {
        _amountController.clear();
        wallet.loadAllBalances(auth.walletAddress!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collateral locked successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(collateral.errorMessage ?? 'Failed to lock collateral'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Collateral'),
        ),
        body: Consumer2<CollateralProvider, WalletProvider>(
          builder: (context, collateral, wallet, _) {
            if (collateral.isLoading && collateral.collaterals.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet balance card
                  _buildWalletBalanceCard(wallet),
                  const SizedBox(height: 20),

                  // Summary cards
                  _buildSummaryCards(collateral),
                  const SizedBox(height: 28),

                  // Lock collateral section
                  _buildLockSection(),
                  const SizedBox(height: 28),

                  // Collateral entries
                  Text(
                    'Collateral Entries',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildCollateralList(collateral),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletBalanceCard(WalletProvider wallet) {
    final usdcBalance = double.tryParse(wallet.balanceOf('USDC')) ?? 0.0;
    final usdtBalance = double.tryParse(wallet.balanceOf('USDT')) ?? 0.0;
    final totalBalance = usdcBalance + usdtBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 22,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    wallet.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '\$${totalBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 22),
                color: AppTheme.textPrimary.withValues(alpha: 0.6),
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (auth.walletAddress != null) {
                    context
                        .read<WalletProvider>()
                        .loadAllBalances(auth.walletAddress!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Individual token breakdown
          Row(
            children: [
              Expanded(
                child: _buildTokenBalanceChip(
                  symbol: 'USDC',
                  balance: usdcBalance,
                  isLoading: wallet.isLoading,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTokenBalanceChip(
                  symbol: 'USDT',
                  balance: usdtBalance,
                  isLoading: wallet.isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenBalanceChip({
    required String symbol,
    required double balance,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: symbol == 'USDC'
                  ? const Color(0xFF2775CA)
                  : const Color(0xFF26A17B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                symbol == 'USDC' ? '\$' : '₮',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                isLoading
                    ? const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(CollateralProvider collateral) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.lock_outline,
            label: 'Locked',
            value: '\$${collateral.totalLocked.toStringAsFixed(2)}',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Available',
            value: '\$${collateral.totalAvailable.toStringAsFixed(2)}',
            color: AppTheme.positive,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lock Collateral',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Deposit USDC as collateral to join higher-tier pools.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          // Amount input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Amount in USDC',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                ),
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Lock button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _lockCollateral,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Lock Collateral',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollateralList(CollateralProvider collateral) {
    if (collateral.collaterals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          children: [
            Icon(Icons.shield_outlined,
                size: 48,
                color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No collateral locked yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lock USDC collateral to unlock higher pool tiers and lower fees.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children:
            List.generate(collateral.collaterals.length, (i) {
          final entry = collateral.collaterals[i];
          final isLast = i == collateral.collaterals.length - 1;
          return _buildCollateralTile(entry, isLast);
        }),
      ),
    );
  }

  Widget _buildCollateralTile(Map<String, dynamic> entry, bool isLast) {
    final locked =
        double.tryParse(entry['lockedAmount']?.toString() ?? '0') ?? 0;
    final slashed =
        double.tryParse(entry['slashedAmount']?.toString() ?? '0') ?? 0;
    final available =
        double.tryParse(entry['availableBalance']?.toString() ?? '0') ?? 0;
    final poolId = entry['poolId']?.toString();

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
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 22,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poolId != null ? 'Pool ${poolId.substring(0, 8)}...' : 'General',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Locked: \$${locked.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                if (slashed > 0)
                  Text(
                    'Slashed: \$${slashed.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.negative,
                    ),
                  ),
              ],
            ),
          ),
          // Available balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${available.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.positive,
                ),
              ),
              const Text(
                'available',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
