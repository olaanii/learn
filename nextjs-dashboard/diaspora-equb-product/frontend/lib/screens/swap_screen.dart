import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/swap_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/desktop_layout.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountController = TextEditingController();
  Timer? _quoteDebounce;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_scheduleQuoteRefresh);
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _scheduleQuoteRefresh() {
    _quoteDebounce?.cancel();
    _quoteDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final walletAddress = context.read<AuthProvider>().walletAddress ??
          context.read<AuthProvider>().walletService.walletAddress;
      context.read<SwapProvider>().fetchQuote(
            _amountController.text,
            walletAddress: walletAddress,
          );
    });
  }

  Future<void> _initializeIfNeeded() async {
    if (_didInit) {
      return;
    }
    _didInit = true;

    final swap = context.read<SwapProvider>();
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();

    await swap.loadStatus();

    final walletAddress =
        auth.walletAddress ?? auth.walletService.walletAddress;
    if (!mounted || walletAddress == null || walletAddress.isEmpty) {
      return;
    }

    await wallet.loadBalance(walletAddress, token: swap.nativeSymbol);
    for (final token in swap.supportedTokenSymbols) {
      await wallet.loadBalance(walletAddress, token: token);
    }
    await swap.fetchRecentSwaps(walletAddress);
  }

  @override
  Widget build(BuildContext context) {
    if (!_didInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeIfNeeded();
      });
    }

    return Consumer3<SwapProvider, WalletProvider, AuthProvider>(
      builder: (context, swap, wallet, auth, _) {
        final amount = double.tryParse(_amountController.text.trim()) ?? 0;
        final canSwap =
            amount > 0 && !swap.isBusy && swap.readinessMessage == null;

        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Swap', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text('Convert between tokens instantly',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (swap.isLoadingStatus)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (swap.readinessMessage != null) ...[
                _buildBanner(
                  context,
                  swap.readinessMessage!,
                  background: Theme.of(context).colorScheme.surface,
                  foreground: AppTheme.textPrimaryColor(context),
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 16),
              ],
              if (swap.errorMessage != null) ...[
                _buildBanner(
                  context,
                  swap.errorMessage!,
                  background: Theme.of(context).colorScheme.errorContainer,
                  foreground: Theme.of(context).colorScheme.onErrorContainer,
                  icon: Icons.error_outline_rounded,
                ),
                const SizedBox(height: 16),
              ],
              if (swap.statusMessage != null) ...[
                _buildBanner(
                  context,
                  swap.statusMessage!,
                  background: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  foreground: AppTheme.textPrimaryColor(context),
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 16),
              ],
              _buildFromCard(context, wallet, swap),
              Center(
                child: GestureDetector(
                  onTap: swap.isBusy
                      ? null
                      : () {
                          swap.swapDirection();
                          _scheduleQuoteRefresh();
                        },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.buttonColor(context),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.subtleShadowFor(context),
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: AppTheme.buttonTextColor(context),
                      size: 22,
                    ),
                  ),
                ),
              ),
              _buildToCard(context, swap),
              const SizedBox(height: 16),
              _buildRateDisplay(context, amount, swap),
              const SizedBox(height: 8),
              _buildPriceImpact(context, swap),
              const SizedBox(height: 8),
              _buildFeeRow(context, swap),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSwap
                      ? () => _handleSwap(context, swap, wallet, auth)
                      : null,
                  child: swap.isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.buttonTextColor(context),
                          ),
                        )
                      : Text(
                          swap.isCheckingAllowance
                              ? 'Checking approval...'
                              : (swap.requiresApproval
                                  ? 'Approve & Swap'
                                  : 'Swap'),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              _buildGasEstimate(context, swap.nativeSymbol),
            ],
          ],
        );

        if (AppTheme.isDesktop(context)) {
          return SingleChildScrollView(
            child: DesktopContent(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: DesktopCardSection(child: form),
                  ),
                  const SizedBox(width: AppTheme.desktopPanelGap),
                  Expanded(
                    flex: 4,
                    child: DesktopCardSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Swaps',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          _buildRecentSwaps(context, swap),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              form,
              const SizedBox(height: 32),
              Text('Recent Swaps',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildRecentSwaps(context, swap),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBanner(
    BuildContext context,
    String message, {
    required Color background,
    required Color foreground,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFromCard(
    BuildContext context,
    WalletProvider wallet,
    SwapProvider swap,
  ) {
    final balance = wallet.balanceOf(swap.fromToken);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('From', style: Theme.of(context).textTheme.bodySmall),
              Text('Balance: $balance',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTokenSelector(context, swap, swap.fromToken, (token) {
                swap.setFromToken(token);
                _scheduleQuoteRefresh();
              }),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                _amountController.text = balance;
                _scheduleQuoteRefresh();
              },
              child: const Text('MAX',
                  style: TextStyle(
                      color: AppTheme.accentYellowDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToCard(BuildContext context, SwapProvider swap) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To (estimated)', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTokenSelector(context, swap, swap.toToken, (token) {
                swap.setToToken(token);
                _scheduleQuoteRefresh();
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    swap.isLoadingQuote ? 'Quoting...' : (swap.quote ?? '0.00'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: AppTheme.textTertiaryColor(context))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector(
    BuildContext context,
    SwapProvider swap,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      initialValue: selected,
      itemBuilder: (_) => swap.availableTokens
          .map((t) => PopupMenuItem(value: t, child: Text(t)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.token_rounded,
                size: 18, color: AppTheme.textPrimaryColor(context)),
            const SizedBox(width: 6),
            Text(selected, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppTheme.textSecondaryColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRateDisplay(
    BuildContext context,
    double amount,
    SwapProvider swap,
  ) {
    final quote = double.tryParse(swap.quote ?? '');
    final rate = amount > 0 && quote != null ? quote / amount : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Rate', style: Theme.of(context).textTheme.bodySmall),
          Text(
            rate == null
                ? 'Enter an amount to see a live quote'
                : '1 ${swap.fromToken} ≈ ${rate.toStringAsFixed(6)} ${swap.toToken}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceImpact(BuildContext context, SwapProvider swap) {
    final impact = swap.priceImpact;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Price Impact', style: Theme.of(context).textTheme.bodySmall),
        Text(
          impact == null ? 'Pending quote' : '${impact.toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 12,
            color: (impact ?? 0) >= 3
                ? Theme.of(context).colorScheme.error
                : AppTheme.positive,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRow(BuildContext context, SwapProvider swap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Protocol Fee', style: Theme.of(context).textTheme.bodySmall),
        Text(
          swap.fee == null ? 'Pending quote' : '${swap.fee} ${swap.fromToken}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildGasEstimate(BuildContext context, String nativeSymbol) {
    return Center(
      child: Text('Estimated gas: ~0.001 $nativeSymbol',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildRecentSwaps(BuildContext context, SwapProvider swap) {
    if (swap.recentSwaps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.swap_horiz_rounded,
                  size: 40, color: AppTheme.textTertiaryColor(context)),
              const SizedBox(height: 8),
              Text('No swaps yet',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Your recent swap submissions will appear here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Column(
        children: swap.recentSwaps.take(5).map((item) {
          final timestamp = (item['timestamp'] as num?)?.toInt();
          final subtitle =
              '${item['amountIn'] ?? '--'} ${item['fromToken'] ?? ''} -> ${item['estimatedOutput'] ?? '--'} ${item['toToken'] ?? ''}';
          final txHash = (item['txHash'] as String?) ?? 'pending';
          return ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: Text(subtitle),
            subtitle: Text(
              timestamp == null
                  ? txHash
                  : '${DateTime.fromMillisecondsSinceEpoch(timestamp)}\n$txHash',
            ),
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleSwap(
    BuildContext context,
    SwapProvider swap,
    WalletProvider wallet,
    AuthProvider auth,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final walletAddress =
        auth.walletAddress ?? auth.walletService.walletAddress;
    if (walletAddress == null || walletAddress.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Connect and bind your wallet before swapping.'),
        ),
      );
      return;
    }

    final txHash = await swap.executeSwap(
      amountText: _amountController.text,
      walletAddress: walletAddress,
    );

    if (!mounted) {
      return;
    }

    if (txHash == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(swap.errorMessage ?? 'Swap failed')),
      );
      return;
    }

    await wallet.loadBalance(walletAddress, token: swap.nativeSymbol);
    for (final token in swap.supportedTokenSymbols) {
      await wallet.loadBalance(walletAddress, token: token);
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Swap submitted: $txHash')),
    );
  }
}
