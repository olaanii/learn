import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/collateral_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_service.dart';

class CollateralScreen extends StatefulWidget {
  const CollateralScreen({super.key});

  @override
  State<CollateralScreen> createState() => _CollateralScreenState();
}

class _CollateralScreenState extends State<CollateralScreen> {
  final _depositController = TextEditingController();
  final _releaseController = TextEditingController();
  bool _isDepositing = false;
  bool _isReleasing = false;
  String _selectedToken = 'USDC';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _depositController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _depositController.removeListener(_onAmountChanged);
    _depositController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

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

  Future<void> _depositCollateral() async {
    final amount = _depositController.text.trim();
    if (amount.isEmpty) return;

    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null || parsedAmount <= 0) return;

    final auth = context.read<AuthProvider>();
    final walletSvc = context.read<WalletService>();
    final collateral = context.read<CollateralProvider>();
    final wallet = context.read<WalletProvider>();

    if (auth.walletAddress == null) return;

    if (!walletSvc.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connect your wallet first')),
        );
      }
      return;
    }

    final tokenBalance =
        double.tryParse(wallet.balanceOf(_selectedToken)) ?? 0.0;
    if (parsedAmount > tokenBalance) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient $_selectedToken balance (\$${tokenBalance.toStringAsFixed(2)})',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _isDepositing = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locking $amount $_selectedToken as collateral — confirm in your wallet...',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final txHash = await collateral.buildAndSignDepositToken(
      amount: amount,
      walletAddress: auth.walletAddress!,
      tokenSymbol: _selectedToken,
    );

    if (!mounted) return;
    setState(() => _isDepositing = false);

    if (txHash != null) {
      _depositController.clear();
      await wallet.loadAllBalances(auth.walletAddress!);
      if (!mounted) return;

      final addr = auth.walletAddress!;
      Future.delayed(const Duration(milliseconds: 800), () {
        collateral.loadCollateral(addr);
        wallet.loadAllBalances(addr);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_selectedToken collateral locked! TX: ${txHash.substring(0, 16)}...',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(collateral.errorMessage ?? 'Deposit failed or rejected'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _releaseCollateral() async {
    final amount = _releaseController.text.trim();
    if (amount.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final collateral = context.read<CollateralProvider>();
    final wallet = context.read<WalletProvider>();

    if (auth.walletAddress == null) return;

    final available = collateral.totalLocked;
    final requestedAmount = double.tryParse(amount) ?? 0;
    if (requestedAmount <= 0 || requestedAmount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestedAmount > available
                ? 'Amount exceeds locked balance (\$${available.toStringAsFixed(2)})'
                : 'Enter a valid amount',
          ),
        ),
      );
      return;
    }

    setState(() => _isReleasing = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Releasing $amount $_selectedToken from collateral...',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    final txHash = await collateral.releaseTokenCollateral(
      walletAddress: auth.walletAddress!,
      amount: amount,
      tokenSymbol: _selectedToken,
    );

    if (!mounted) return;
    setState(() => _isReleasing = false);

    if (txHash != null) {
      _releaseController.clear();
      await wallet.loadAllBalances(auth.walletAddress!);
      if (!mounted) return;

      final addr = auth.walletAddress!;
      Future.delayed(const Duration(milliseconds: 800), () {
        collateral.loadCollateral(addr);
        wallet.loadAllBalances(addr);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collateral released! $_selectedToken returned to your wallet.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(collateral.errorMessage ?? 'Release failed'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
                  _buildWalletBalanceCard(wallet),
                  const SizedBox(height: 20),
                  _buildSummaryCards(collateral),
                  const SizedBox(height: 28),
                  _buildDepositSection(collateral, wallet),
                  const SizedBox(height: 20),
                  _buildReleaseSection(collateral),
                  const SizedBox(height: 28),
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
                    context
                        .read<CollateralProvider>()
                        .loadCollateral(auth.walletAddress!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            subtitle: 'USDC/USDT collateral',
            value: '\$${collateral.totalLocked.toStringAsFixed(2)}',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.lock_open_outlined,
            label: 'Available',
            subtitle: 'Can be released',
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
    String? subtitle,
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
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector() {
    return Row(
      children: [
        _buildTokenOption('USDC', const Color(0xFF2775CA), '\$'),
        const SizedBox(width: 10),
        _buildTokenOption('USDT', const Color(0xFF26A17B), '₮'),
      ],
    );
  }

  Widget _buildTokenOption(String symbol, Color color, String icon) {
    final isSelected = _selectedToken == symbol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedToken = symbol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepositSection(
    CollateralProvider collateral,
    WalletProvider wallet,
  ) {
    final tokenBalance =
        double.tryParse(wallet.balanceOf(_selectedToken)) ?? 0.0;
    final depositAmount = double.tryParse(_depositController.text.trim()) ?? 0;
    final hasValidAmount = depositAmount > 0 && depositAmount <= tokenBalance;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 18, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock Collateral',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lock USDC or USDT to join higher-tier pools.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Token selector
          _buildTokenSelector(),
          const SizedBox(height: 14),

          // Current balance of selected token
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: _selectedToken == 'USDC'
                      ? const Color(0xFF2775CA)
                      : const Color(0xFF26A17B),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_selectedToken balance: ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '\$${tokenBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Amount input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: TextField(
              controller: _depositController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Amount ($_selectedToken)',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                ),
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
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

          // Balance deduction preview
          if (depositAmount > 0) ...[
            const SizedBox(height: 12),
            _buildBalancePreview(
              label: 'After locking',
              currentBalance: tokenBalance,
              changeAmount: depositAmount,
              isDeduction: true,
              tokenSymbol: _selectedToken,
              isValid: hasValidAmount,
            ),
          ],

          const SizedBox(height: 6),
          const Text(
            'Your wallet (MetaMask) will pop up to sign this transaction.',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_isDepositing || collateral.isLoading || !hasValidAmount)
                      ? null
                      : _depositCollateral,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: _isDepositing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Lock $_selectedToken & Sign',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildBalancePreview({
    required String label,
    required double currentBalance,
    required double changeAmount,
    required bool isDeduction,
    required String tokenSymbol,
    required bool isValid,
  }) {
    final afterBalance = isDeduction
        ? currentBalance - changeAmount
        : currentBalance + changeAmount;
    final isNegative = afterBalance < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNegative
            ? Colors.red.shade50
            : AppTheme.positive.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(
          color: isNegative
              ? Colors.red.shade200
              : AppTheme.positive.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current $tokenSymbol',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              Text(
                '\$${currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDeduction ? 'Locking' : 'Receiving',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              Text(
                '${isDeduction ? '-' : '+'}\$${changeAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDeduction ? AppTheme.negative : AppTheme.positive,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\$${afterBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isNegative ? Colors.red : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (isNegative) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text(
                  'Insufficient $tokenSymbol balance',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReleaseSection(CollateralProvider collateral) {
    final hasLocked = collateral.totalLocked > 0;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.positive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_outlined,
                    size: 18, color: AppTheme.positive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Release Collateral',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocked
                          ? 'Release locked USDC/USDT back to your wallet.'
                          : 'No locked collateral to release.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.positive.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppTheme.cardRadiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: AppTheme.positive),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Locked: \$${collateral.totalLocked.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius:
                    BorderRadius.circular(AppTheme.cardRadiusSmall),
                border:
                    Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: TextField(
                controller: _releaseController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Amount (max ${collateral.totalLocked.toStringAsFixed(2)})',
                  hintStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textHint,
                  ),
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
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
            const SizedBox(height: 6),
            const Text(
              'Tokens will be sent back to your wallet by the system.',
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isReleasing || collateral.isLoading)
                    ? null
                    : _releaseCollateral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.positive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isReleasing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Release Collateral',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
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
              'Lock USDC or USDT as collateral to unlock higher pool tiers and lower fees.',
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
        children: List.generate(collateral.collaterals.length, (i) {
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
    final source = entry['source']?.toString() ?? 'token';
    final poolId = entry['poolId']?.toString();

    final isCtc = source == 'on-chain-ctc';
    final tokenLabel = isCtc ? 'CTC' : 'USDC/USDT';

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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCtc
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : const Color(0xFF2775CA).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 22,
              color: isCtc
                  ? AppTheme.primaryColor
                  : const Color(0xFF2775CA),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poolId != null
                      ? 'Pool ${poolId.length > 8 ? poolId.substring(0, 8) : poolId}...'
                      : '$tokenLabel Collateral',
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
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
