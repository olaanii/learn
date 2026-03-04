import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String _amount = '';
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
    });
  }

  String get _formattedAmount {
    if (_amount.isEmpty) return '\$0';
    final parts = _amount.split('.');
    // Add comma formatting for integer part
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
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress == null || _amount.isEmpty) return;

    // For MVP: prompt for recipient address
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
      message: 'Opening MetaMask to confirm…',
      dedupeKey: 'pay_metamask_opening',
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
              child: Column(
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formattedAmount,
                    style: TextStyle(
                      fontSize: 48,
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentYellow),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.textHintColor(context).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.textTertiaryColor(context)),
                        const SizedBox(width: 10),
                        Text('Add a note (optional)', style: TextStyle(fontSize: 14, color: AppTheme.textTertiaryColor(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildNumpad(context)),
                  const SizedBox(height: 12),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _handleSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.buttonColor(context),
                          foregroundColor: AppTheme.buttonTextColor(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.buttonTextColor(context), strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Send', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20, color: AppTheme.buttonTextColor(context)),
                                ],
                              ),
                      ),
                    ),
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

  Widget _buildRecipientCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
        border: Border.all(color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.textTertiaryColor(context))),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 22, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _recipientController,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Name, tag, or address',
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.textTertiaryColor(context)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text('Contacts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)),
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
        final buttonHeight = ((constraints.maxHeight - 18) / 4).clamp(36.0, 64.0);

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
                          ? Icon(Icons.backspace_outlined, size: 22, color: AppTheme.textPrimaryColor(context))
                          : Text(key, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
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
