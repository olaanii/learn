import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a recipient address')),
      );
      return;
    }

    setState(() => _isSending = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening MetaMask to confirm…'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final txHash = await wallet.buildAndSignTransfer(
      from: auth.walletAddress!,
      to: recipient,
      amount: _amount,
      token: wallet.token,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (txHash != null) {
      await wallet.refreshAfterTx(auth.walletAddress!, token: wallet.token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent! Tx: $txHash'),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wallet.errorMessage ?? 'Transfer failed'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        return Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Pay'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 22),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Column(
              children: [
                // Card chip on green background
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildCardChip(),
                  ),
                ),
                // White card panel for content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        children: [
                          // Recipient
                          _buildRecipientCard(),
                          const SizedBox(height: 28),
                          // Amount
                          Text(
                            _formattedAmount,
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Balance: \$${wallet.balance}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Note
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sticky_note_2_outlined,
                                  size: 18, color: AppTheme.textTertiary),
                              SizedBox(width: 6),
                              Text(
                                'Note',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Number pad
                          Expanded(child: _buildNumpad()),
                          const SizedBox(height: 16),
                          // Send button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSending ? null : _handleSend,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.darkButton,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: _isSending
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Send',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkButton,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 22,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _recipientController,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Recipient address (0x...)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Could open a contact picker / QR scanner
            },
            child: const Text(
              'Paste',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

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
                if (key.isEmpty) {
                  return SizedBox(width: buttonSize, height: buttonHeight);
                }
                return GestureDetector(
                  onTap: () => _onKeyTap(key),
                  child: Container(
                    width: buttonSize,
                    height: buttonHeight,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: key == 'backspace'
                          ? Colors.transparent
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: key == 'backspace'
                          ? const Icon(Icons.backspace_outlined,
                              size: 22, color: AppTheme.textPrimary)
                          : Text(
                              key,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
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
