import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
import '../widgets/desktop_layout.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String _amount = '';
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  bool _isSending = false;

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (key == '.') {
        if (!_amount.contains('.')) {
          _amount += '.';
        }
      } else {
        if (_amount == '0') {
          _amount = key;
        } else {
          _amount += key;
        }
      }
      _amountController.value = TextEditingValue(
        text: _amount,
        selection: TextSelection.collapsed(offset: _amount.length),
      );
    });
  }

  String get _formattedAmount {
    if (_amount.isEmpty) return '\$0';
    final parts = _amount.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    if (parts.length > 1) {
      return '\$${buffer.toString()}.${parts[1]}';
    }
    return '\$${buffer.toString()}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final normalized = value.replaceAll(',', '');
    setState(() {
      _amount = normalized;
    });
  }

  Future<void> _handleSend() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress == null || _amount.isEmpty) return;

    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      AppSnackbarService.instance.error(
        message: 'Enter a recipient address',
        dedupeKey: 'pay_missing_recipient',
      );
      return;
    }

    setState(() => _isSending = true);

    AppSnackbarService.instance.info(
      message: 'Opening wallet to confirm...',
      dedupeKey: 'pay_wallet_opening',
      duration: const Duration(seconds: 2),
    );

    final txHash = await wallet.buildAndSignTransfer(
      from: auth.walletAddress!,
      to: recipient,
      amount: _amount,
      token: wallet.token,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (txHash != null) {
      context.read<NotificationProvider>().triggerFastSync();
      await wallet.refreshAfterTx(auth.walletAddress!, token: wallet.token);

      if (!mounted) return;
      AppSnackbarService.instance.success(
        message: 'Sent! Tx: $txHash',
        dedupeKey: 'pay_success_$txHash',
        duration: const Duration(seconds: 4),
      );
    } else {
      AppSnackbarService.instance.error(
        message: wallet.errorMessage ?? 'Transfer failed',
        dedupeKey: 'pay_failed',
      );
    }
  }

  Color _numpadKeyColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.backgroundLight;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        return Container(
          decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Send Payment'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppTheme.isDesktop(context)
                  ? DesktopContent(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: DesktopCardSection(
                              child: _buildPaymentSummary(context, wallet),
                            ),
                          ),
                          const SizedBox(width: AppTheme.desktopPanelGap),
                          Expanded(
                            flex: 4,
                            child: DesktopCardSection(
                              child: _buildDesktopTransferForm(context, wallet),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildPaymentSummary(context, wallet, mobile: true),
                        const SizedBox(height: 16),
                        Expanded(child: _buildNumpad(context)),
                        const SizedBox(height: 12),
                        SafeArea(
                          top: false,
                          child: _buildSendButton(context),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentSummary(BuildContext context, WalletProvider wallet,
      {bool mobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecipientCard(context),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.textHintColor(context).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Balance: \$${wallet.balance}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _formattedAmount,
          style: TextStyle(
            fontSize: mobile ? 48 : 56,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentYellow.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'No fees via Equb Network',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentYellow,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.textHintColor(context).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: AppTheme.textTertiaryColor(context),
              ),
              const SizedBox(width: 10),
              Text(
                'Add a note (optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSending ? null : _handleSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonColor(context),
          foregroundColor: AppTheme.buttonTextColor(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: _isSending
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.buttonTextColor(context),
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Send',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: AppTheme.buttonTextColor(context),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopTransferForm(
      BuildContext context, WalletProvider wallet) {
    final balance = double.tryParse(wallet.balance) ?? 0;
    final amount = double.tryParse(_amount) ?? 0;
    final remaining = (balance - amount).clamp(0, double.infinity);
    final eurRate = wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Use normal desktop text input for amount entry.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _onAmountChanged,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: '0.00',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.textHintColor(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.textHintColor(context).withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              _buildInfoRow(context, 'Exchange rate', '1 USD = $eurRate EUR'),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Balance after transfer',
                  '\$${remaining.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  context, 'Transaction fee', '\$0.00 (free transfer)'),
            ],
          ),
        ),
        const Spacer(),
        _buildSendButton(context),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiaryColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
        border: Border.all(
            color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _recipientController,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Name, tag, or address',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiaryColor(context),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Contacts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'backspace'],
    ];
    final keyBg = _numpadKeyColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize = (constraints.maxWidth - 24) / 3;
        final buttonHeight =
            ((constraints.maxHeight - 18) / 4).clamp(36.0, 64.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                return GestureDetector(
                  onTap: () => _onKeyTap(key),
                  child: Container(
                    width: buttonSize,
                    height: buttonHeight,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: key == 'backspace' ? Colors.transparent : keyBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: key == 'backspace'
                          ? Icon(
                              Icons.backspace_outlined,
                              size: 22,
                              color: AppTheme.textPrimaryColor(context),
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }
}
