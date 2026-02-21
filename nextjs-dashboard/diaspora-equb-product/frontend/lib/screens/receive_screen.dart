import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _currency = 'USDC';

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String _shortenAddress(String? address) {
    if (address == null || address.length < 12) return address ?? '—';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final walletAddr = auth.walletAddress;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Receive'),
          actions: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5E7EB),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://i.pravatar.cc/150?img=12',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.sync_rounded, size: 22),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.show_chart_rounded, size: 22),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 4),
            // White card panel
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Consumer<WalletProvider>(
                    builder: (context, wallet, _) {
                      final amountStr = _amountController.text;
                      final usdAmount = double.tryParse(amountStr) ?? 0;
                      final eurRate = wallet.rates['EUR'] ?? 0.95;
                      final eurAmount = usdAmount * eurRate;
                      final now = TimeOfDay.now();
                      final timeStr =
                          '${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

                      return Column(
                        children: [
                          // Your wallet address card
                          _buildWalletAddressCard(walletAddr),
                          const SizedBox(height: 16),
                          // Client pays card
                          _buildAmountCard(
                            label: 'Client pays',
                            amount: usdAmount > 0
                                ? '\$${usdAmount.toStringAsFixed(2)}'
                                : '\$0.00',
                            time: timeStr,
                          ),
                          const SizedBox(height: 12),
                          // Arrow down
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // You receive card
                          _buildAmountCard(
                            label: 'You receive',
                            amount: usdAmount > 0
                                ? '€${eurAmount.toStringAsFixed(2)}'
                                : '€0.00',
                            time: timeStr,
                          ),
                          const SizedBox(height: 20),
                          // Exchange rate
                          Builder(
                            builder: (context) {
                              final eur =
                                  wallet.rates['EUR']?.toStringAsFixed(2) ??
                                      '0.95';
                              final gbp =
                                  wallet.rates['GBP']?.toStringAsFixed(2) ??
                                      '0.79';
                              return Text(
                                '1 USD = EUR $eur • GBP $gbp',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textTertiary,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          // Action buttons
                          _buildActionButtons(walletAddr),
                          const SizedBox(height: 32),
                          // Amount input
                          _buildAmountInput(),
                          const SizedBox(height: 20),
                          // Reference ID input
                          _buildReferenceInput(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletAddressCard(String? walletAddr) {
    return GestureDetector(
      onTap: () {
        if (walletAddr != null) {
          Clipboard.setData(ClipboardData(text: walletAddr));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet address copied'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.positive.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppTheme.positive),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Wallet Address',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortenAddress(walletAddr),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.content_copy_rounded,
                size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard({
    required String label,
    required String amount,
    required String time,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          // Yellow inner section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: AppTheme.accentYellow,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.textPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.content_copy_rounded,
                        size: 16,
                        color: AppTheme.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Amount
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 4),
                // Time
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textPrimary.withValues(alpha: 0.45),
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

  Widget _buildActionButtons(String? walletAddr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionItem(Icons.qr_code_scanner_rounded, 'Scan QR', () {}),
        _buildActionItem(Icons.share_outlined, 'Share', () {
          if (walletAddr != null) {
            Clipboard.setData(ClipboardData(text: walletAddr));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Wallet address copied to share'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }),
        _buildActionItem(Icons.more_horiz_rounded, 'More', () {}),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 22, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter amount',
                hintStyle: TextStyle(
                  fontSize: 18,
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
          GestureDetector(
            onTap: () {
              setState(() {
                _currency = _currency == 'USDC' ? 'EUR' : 'USDC';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _currency,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppTheme.textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextField(
        controller: _referenceController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: const InputDecoration(
          labelText: 'Reference ID (optional)',
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.textTertiary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
