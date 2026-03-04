import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/network_provider.dart';
import '../providers/wallet_provider.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  String? _fromToken;
  String _toToken = 'USDC';
  final _amountController = TextEditingController();
  bool _isSwapping = false;

  List<String> _tokens(BuildContext context) {
    final sym = context.read<NetworkProvider>().nativeSymbol;
    return [sym, 'USDC', 'USDT'];
  }

  String _fromTokenValue(BuildContext context) {
    return _fromToken ?? context.read<NetworkProvider>().nativeSymbol;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _swapTokens() {
    setState(() {
      final temp = _fromTokenValue(context);
      _fromToken = _toToken;
      _toToken = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Swap', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('Convert between tokens instantly',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              _buildFromCard(context, wallet),
              Center(
                child: GestureDetector(
                  onTap: _swapTokens,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.buttonColor(context),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.subtleShadowFor(context),
                    ),
                    child: Icon(Icons.swap_vert_rounded, color: AppTheme.buttonTextColor(context), size: 22),
                  ),
                ),
              ),
              _buildToCard(context),
              const SizedBox(height: 16),
              _buildRateDisplay(context),
              const SizedBox(height: 8),
              _buildPriceImpact(context),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSwap ? _handleSwap : null,
                  child: _isSwapping
                      ? SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.buttonTextColor(context)))
                      : const Text('Swap'),
                ),
              ),
              const SizedBox(height: 8),
              _buildGasEstimate(context),
              const SizedBox(height: 32),
              Text('Recent Swaps', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildRecentSwaps(context),
            ],
          ),
        );
      },
    );
  }

  bool get _canSwap {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount > 0 && !_isSwapping;
  }

  Widget _buildFromCard(BuildContext context, WalletProvider wallet) {
    final from = _fromTokenValue(context);
    final nativeSym = context.read<NetworkProvider>().nativeSymbol;
    final balance = wallet.balanceOf(from == nativeSym ? 'USDC' : from);
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
              Text('Balance: $balance', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTokenSelector(context, from, (t) => setState(() {
                if (t == _toToken) _toToken = from;
                _fromToken = t;
              })),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.headlineMedium,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true,
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
              onTap: () => _amountController.text = balance,
              child: const Text('MAX', style: TextStyle(color: AppTheme.accentYellowDark,
                  fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToCard(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final estimated = amount > 0 ? (amount * 0.98).toStringAsFixed(4) : '0.00';

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
              _buildTokenSelector(context, _toToken, (t) => setState(() {
                if (t == _fromTokenValue(context)) _fromToken = _toToken;
                _toToken = t;
              })),
              const SizedBox(width: 12),
              Expanded(
                child: Text(estimated,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textTertiaryColor(context))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector(BuildContext context, String selected, ValueChanged<String> onChanged) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      initialValue: selected,
      itemBuilder: (_) => _tokens(context).map((t) => PopupMenuItem(value: t, child: Text(t))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.token_rounded, size: 18, color: AppTheme.textPrimaryColor(context)),
            const SizedBox(width: 6),
            Text(selected, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textSecondaryColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRateDisplay(BuildContext context) {
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
          Text('1 ${_fromTokenValue(context)} ≈ 0.98 $_toToken', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildPriceImpact(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Price Impact', style: Theme.of(context).textTheme.bodySmall),
        const Text('< 0.1%', style: TextStyle(fontSize: 12, color: AppTheme.positive, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildGasEstimate(BuildContext context) {
    return Center(
      child: Text('Estimated gas: ~0.001 ${context.read<NetworkProvider>().nativeSymbol}',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildRecentSwaps(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.swap_horiz_rounded, size: 40, color: AppTheme.textTertiaryColor(context)),
            const SizedBox(height: 8),
            Text('No swaps yet', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Swap history will appear here once the swap contract is deployed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSwap() async {
    setState(() => _isSwapping = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSwapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap will be available when SwapRouter contract is deployed')),
      );
    }
  }
}
