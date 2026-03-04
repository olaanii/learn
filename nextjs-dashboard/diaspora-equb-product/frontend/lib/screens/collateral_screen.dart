import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/collateral_provider.dart';
import '../providers/network_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
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
      AppSnackbarService.instance.warning(
        message: 'Connect your wallet first',
        dedupeKey: 'collateral_wallet_not_connected',
      );
      return;
    }

    final tokenBalance =
        double.tryParse(wallet.balanceOf(_selectedToken)) ?? 0.0;
    if (parsedAmount > tokenBalance) {
      AppSnackbarService.instance.error(
        message:
            'Insufficient $_selectedToken balance (\$${tokenBalance.toStringAsFixed(2)})',
        dedupeKey: 'collateral_insufficient_balance',
      );
      return;
    }

    setState(() => _isDepositing = true);

    AppSnackbarService.instance.info(
      message:
          'Locking $amount $_selectedToken as collateral — confirm in your wallet...',
      dedupeKey: 'collateral_deposit_pending',
      duration: const Duration(seconds: 4),
    );

    final txHash = await collateral.buildAndSignDepositToken(
      amount: amount,
      walletAddress: auth.walletAddress!,
      tokenSymbol: _selectedToken,
    );

    if (!mounted) return;
    setState(() => _isDepositing = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      _depositController.clear();
      await wallet.loadAllBalances(auth.walletAddress!);
      if (!mounted) return;

      final addr = auth.walletAddress!;
      Future.delayed(const Duration(milliseconds: 800), () {
        collateral.loadCollateral(addr);
        wallet.loadAllBalances(addr);
      });

      AppSnackbarService.instance.success(
        message:
            '$_selectedToken collateral locked! TX: ${txHash.substring(0, 16)}...',
        dedupeKey: 'collateral_deposit_success_$txHash',
        duration: const Duration(seconds: 4),
      );
    } else {
      AppSnackbarService.instance.error(
        message: collateral.errorMessage ?? 'Deposit failed or rejected',
        dedupeKey: 'collateral_deposit_failed',
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
      AppSnackbarService.instance.error(
        message: requestedAmount > available
            ? 'Amount exceeds locked balance (\$${available.toStringAsFixed(2)})'
            : 'Enter a valid amount',
        dedupeKey: 'collateral_release_invalid_amount',
      );
      return;
    }

    setState(() => _isReleasing = true);

    AppSnackbarService.instance.info(
      message: 'Releasing $amount $_selectedToken from collateral...',
      dedupeKey: 'collateral_release_pending',
      duration: const Duration(seconds: 3),
    );

    final txHash = await collateral.releaseTokenCollateral(
      walletAddress: auth.walletAddress!,
      amount: amount,
      tokenSymbol: _selectedToken,
    );

    if (!mounted) return;
    setState(() => _isReleasing = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      _releaseController.clear();
      await wallet.loadAllBalances(auth.walletAddress!);
      if (!mounted) return;

      final addr = auth.walletAddress!;
      Future.delayed(const Duration(milliseconds: 800), () {
        collateral.loadCollateral(addr);
        wallet.loadAllBalances(addr);
      });

      AppSnackbarService.instance.success(
        message:
            'Collateral released! $_selectedToken returned to your wallet.',
        dedupeKey: 'collateral_release_success_$txHash',
        duration: const Duration(seconds: 4),
      );
    } else {
      AppSnackbarService.instance.error(
        message: collateral.errorMessage ?? 'Release failed',
        dedupeKey: 'collateral_release_failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
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
                  _buildWalletBalanceCard(context, wallet),
                  const SizedBox(height: 20),
                  _buildSummaryCards(context, collateral),
                  const SizedBox(height: 28),
                  _buildDepositSection(context, collateral, wallet),
                  const SizedBox(height: 20),
                  _buildReleaseSection(context, collateral),
                  const SizedBox(height: 28),
                  Text(
                    'Collateral Entries',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildCollateralList(context, collateral),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletBalanceCard(BuildContext context, WalletProvider wallet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usdcBalance = double.tryParse(wallet.balanceOf('USDC')) ?? 0.0;
    final usdtBalance = double.tryParse(wallet.balanceOf('USDT')) ?? 0.0;
    final totalBalance = usdcBalance + usdtBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadowFor(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
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
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 16, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          wallet.isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  '\$${totalBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
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
    final color = symbol == 'USDC' ? AppTheme.accentYellow : AppTheme.positive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                symbol == 'USDC' ? '\$' : '₮',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                  ),
                ),
                Text(
                  isLoading ? '...' : '\$${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, CollateralProvider collateral) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context: context,
            icon: Icons.lock_outline,
            label: 'Locked',
            value: '\$${collateral.totalLocked.toStringAsFixed(2)}',
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkPrimary
                : AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context: context,
            icon: Icons.lock_open_outlined,
            label: 'Available',
            value: '\$${collateral.totalAvailable.toStringAsFixed(2)}',
            color: AppTheme.positive,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTokenTab('USDC', '\$'),
          _buildTokenTab('USDT', '₮'),
        ],
      ),
    );
  }

  Widget _buildTokenTab(String symbol, String icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedToken == symbol;
    final color = symbol == 'USDC'
        ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
        : AppTheme.positive;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedToken = symbol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.cardColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? AppTheme.subtleShadowFor(context) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.textPrimaryColor(context)
                      : AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepositSection(
    BuildContext context,
    CollateralProvider collateral,
    WalletProvider wallet,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenBalance =
        double.tryParse(wallet.balanceOf(_selectedToken)) ?? 0.0;
    final depositAmount = double.tryParse(_depositController.text.trim()) ?? 0;
    final hasValidAmount = depositAmount > 0 && depositAmount <= tokenBalance;
    final tokenColor = _selectedToken == 'USDC'
        ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
        : AppTheme.positive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lock Collateral',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lock USDC or USDT to join higher-tier equbs.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          const SizedBox(height: 18),

          // Token selector
          _buildTokenSelector(context),
          const SizedBox(height: 16),

          // Amount input with balance display
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurface
                  : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.textHintColor(context).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _depositController.text =
                              tokenBalance.toStringAsFixed(2);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 13, color: tokenColor),
                            const SizedBox(width: 4),
                            Text(
                              '\$${tokenBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokenColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MAX',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: tokenColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: TextField(
                    controller: _depositController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textHintColor(context),
                      ),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Balance deduction preview
          if (depositAmount > 0) ...[
            const SizedBox(height: 12),
            _buildBalancePreview(
              context: context,
              label: 'After locking',
              currentBalance: tokenBalance,
              changeAmount: depositAmount,
              isDeduction: true,
              tokenSymbol: _selectedToken,
              isValid: hasValidAmount,
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_isDepositing || collateral.isLoading || !hasValidAmount)
                      ? null
                      : _depositCollateral,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor(context),
                foregroundColor: AppTheme.buttonTextColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isDepositing
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.buttonTextColor(context),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Lock $_selectedToken & Sign',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your wallet will pop up to sign this transaction.',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textTertiaryColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancePreview({
    required BuildContext context,
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
            ? AppTheme.negative.withValues(alpha: 0.06)
            : AppTheme.positive.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(
          color: isNegative
              ? AppTheme.negative.withValues(alpha: 0.2)
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
              Text(
                '\$${currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiaryColor(context),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                '\$${afterBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isNegative ? AppTheme.negative : AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          if (isNegative) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppTheme.negative),
                const SizedBox(width: 4),
                Text(
                  'Insufficient $tokenSymbol balance',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.negative,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReleaseSection(
      BuildContext context, CollateralProvider collateral) {
    final hasLocked = collateral.totalLocked > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_open_outlined,
                size: 20, color: AppTheme.positive),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Release Collateral',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLocked
                      ? 'Locked: \$${collateral.totalLocked.toStringAsFixed(2)}'
                      : 'No locked collateral',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: hasLocked && !_isReleasing
                  ? () => _showReleaseModal(context, collateral)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.positive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                'Release',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Release Modal ──────────────────────────────────────────────────

  void _showReleaseModal(
      BuildContext context, CollateralProvider collateral) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _releaseController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final locked = collateral.totalLocked;
            final releaseAmt =
                double.tryParse(_releaseController.text.trim()) ?? 0;
            final isValid = releaseAmt > 0 && releaseAmt <= locked;
            final afterBalance = locked - releaseAmt;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textHintColor(modalCtx)
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title row
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.positive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock_open_outlined,
                                size: 20, color: AppTheme.positive),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Release Collateral',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        AppTheme.textPrimaryColor(modalCtx),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Unlock tokens back to your wallet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiaryColor(
                                        modalCtx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(modalCtx),
                            child: Icon(Icons.close_rounded,
                                size: 22,
                                color:
                                    AppTheme.textTertiaryColor(modalCtx)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Locked balance banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.positive.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Currently Locked',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondaryColor(
                                    modalCtx),
                              ),
                            ),
                            Text(
                              '\$${locked.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.positive,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount input
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.textHintColor(modalCtx)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Release Amount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textTertiaryColor(
                                          modalCtx),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _releaseController.text =
                                          locked.toStringAsFixed(2);
                                      setModalState(() {});
                                    },
                                    child: const Text(
                                      'MAX',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.positive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 12),
                              child: TextField(
                                controller: _releaseController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                autofocus: true,
                                onChanged: (_) => setModalState(() {}),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor(
                                      modalCtx),
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textHintColor(
                                        modalCtx),
                                  ),
                                  prefixText: '\$ ',
                                  prefixStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor(
                                        modalCtx),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Summary rows
                      _buildModalDetailRow(
                        modalCtx,
                        'After Release',
                        '\$${afterBalance.clamp(0, double.infinity).toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _buildModalDetailRow(
                        modalCtx,
                        'Destination',
                        'Your connected wallet',
                      ),
                      const SizedBox(height: 8),
                      _buildModalDetailRow(
                        modalCtx,
                        'Network Fee',
                        'Included',
                      ),

                      if (releaseAmt > locked) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppTheme.negative),
                            SizedBox(width: 6),
                            Text(
                              'Amount exceeds locked balance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.negative,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isValid && !_isReleasing
                              ? () {
                                  Navigator.pop(modalCtx);
                                  _releaseCollateral();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.positive,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isReleasing
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirm Release',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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

  Widget _buildModalDetailRow(
      BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollateralList(BuildContext context, CollateralProvider collateral) {
    if (collateral.collaterals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.subtleShadowFor(context),
        ),
        child: Column(
          children: [
            Icon(Icons.shield_outlined,
                size: 48, color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No collateral locked yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lock USDC or USDT as collateral to unlock higher equb tiers and lower fees.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        children: List.generate(collateral.collaterals.length, (i) {
          final entry = collateral.collaterals[i];
          final isLast = i == collateral.collaterals.length - 1;
          return _buildCollateralTile(context, entry, isLast);
        }),
      ),
    );
  }

  Widget _buildCollateralTile(BuildContext context, Map<String, dynamic> entry, bool isLast) {
    final locked =
        double.tryParse(entry['lockedAmount']?.toString() ?? '0') ?? 0;
    final slashed =
        double.tryParse(entry['slashedAmount']?.toString() ?? '0') ?? 0;
    final available =
        double.tryParse(entry['availableBalance']?.toString() ?? '0') ?? 0;
    final source = entry['source']?.toString() ?? 'token';
    final poolId = entry['poolId']?.toString();

    final isCtc = source == 'on-chain-ctc';
    final tokenLabel = isCtc ? context.read<NetworkProvider>().nativeSymbol : 'USDC/USDT';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: AppTheme.textHintColor(context).withValues(alpha: 0.3), width: 1),
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
                  : AppTheme.secondaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 22,
              color: isCtc ? AppTheme.primaryColor : AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poolId != null
                      ? 'Equb ${poolId.length > 8 ? poolId.substring(0, 8) : poolId}...'
                      : '$tokenLabel Collateral',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Locked: \$${locked.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
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
              Text(
                'available',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
