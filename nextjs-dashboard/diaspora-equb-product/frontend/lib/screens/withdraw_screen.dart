import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';

class WithdrawScreen extends StatefulWidget {
  final bool standalone;

  const WithdrawScreen({super.key, this.standalone = false});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'USDC';
  String _network = 'ERC-20';
  bool _isSubmitting = false;
  String? _txResult;

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
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
            title: const Text('Withdraw'),
          ),
          body: body,
        ),
      );
    }

    // Embedded mode inside MainShell
    return Column(
      children: [
        // Inline header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                'Withdraw',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 22),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Future<void> _submitWithdraw() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress == null) return;

    final to = _accountController.text.trim();
    final amount = _amountController.text.trim();
    if (to.isEmpty || amount.isEmpty) {
      AppSnackbarService.instance.error(
        message: 'Please fill in all fields',
        dedupeKey: 'withdraw_missing_fields',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    AppSnackbarService.instance.info(
      message: 'Opening MetaMask to confirm…',
      dedupeKey: 'withdraw_metamask_opening',
      duration: const Duration(seconds: 2),
    );

    final txHash = await wallet.buildAndSignWithdraw(
      from: auth.walletAddress!,
      to: to,
      amount: amount,
      token: _currency,
      network: _network,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      await wallet.refreshAfterTx(auth.walletAddress!, token: _currency);
      if (!mounted) return;

      setState(() => _txResult = 'Sent! Tx: ${txHash.substring(0, 10)}…');
      AppSnackbarService.instance.success(
        message: 'Withdraw sent. Tx: $txHash',
        dedupeKey: 'withdraw_success_$txHash',
        duration: const Duration(seconds: 4),
      );
    } else {
      setState(() => _txResult = wallet.errorMessage ?? 'Withdraw failed');
      AppSnackbarService.instance.error(
        message: wallet.errorMessage ?? 'Withdraw failed',
        dedupeKey: 'withdraw_failed',
      );
    }
  }

  Widget _buildBody() {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account address
                _buildSectionLabel(context, 'Account address'),
                const SizedBox(height: 10),
                _buildTextField(
                  context,
                  controller: _accountController,
                  hint: 'Enter wallet address (0x...)',
                ),
                const SizedBox(height: 28),

                // Currency (token)
                _buildSectionLabel(context, 'Currency'),
                const SizedBox(height: 10),
                _buildDropdownField(
                  context,
                  value: _currency,
                  onTap: () {
                    setState(() {
                      _currency = _currency == 'USDC' ? 'USDT' : 'USDC';
                    });
                  },
                ),
                const SizedBox(height: 28),

                // Network
                _buildSectionLabel(context, 'Network'),
                const SizedBox(height: 10),
                _buildNetworkField(context),
                const SizedBox(height: 28),

                // Amount
                _buildSectionLabel(context, 'Amount'),
                const SizedBox(height: 10),
                _buildAmountField(context),
                const SizedBox(height: 8),
                Text(
                  'Available: \$${wallet.balance}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 36),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitWithdraw,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor(context),
                      foregroundColor: AppTheme.buttonTextColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppTheme.buttonTextColor(context),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                if (_txResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.positive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.positive.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      _txResult!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Info rows
                _buildInfoRow(context, 'Fee', '~0.001 ETH'),
                const SizedBox(height: 14),
                _buildInfoRow(context, 'Transaction time', '~15 sec'),
                const SizedBox(height: 14),
                _buildInfoRow(context, 'Network fee', 'Variable'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.textHintColor(context), width: 1),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppTheme.textTertiaryColor(context),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.textHintColor(context), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppTheme.textSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkField(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _network = _network == 'ERC-20' ? 'BEP-20' : 'ERC-20';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.textHintColor(context), width: 1),
        ),
        child: Row(
          children: [
            // Network icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF627EEA).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.currency_exchange_rounded,
                  size: 16,
                  color: Color(0xFF627EEA),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _network,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppTheme.textSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.textHintColor(context), width: 1),
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: InputDecoration(
          prefixText: '\$ ',
          prefixStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiaryColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}
