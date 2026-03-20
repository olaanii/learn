import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
import '../widgets/desktop_layout.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _currency = 'USDC';

  Color _softSurfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.backgroundLight;

  Color _softBorderColor(BuildContext context) =>
      AppTheme.textHintColor(context).withValues(alpha: 0.45);

  Color _softAccentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.textHintColor(context).withValues(alpha: 0.18)
          : const Color(0xFFE4F0E0);

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
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.textHintColor(context).withValues(alpha: 0.3),
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
        body: Consumer<WalletProvider>(
          builder: (context, wallet, _) {
            final amountStr = _amountController.text;
            final usdAmount = double.tryParse(amountStr) ?? 0;
            final eurRate = wallet.rates['EUR'] ?? 0.95;
            final eurAmount = usdAmount * eurRate;
            final now = TimeOfDay.now();
            final timeStr =
                '${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

            return AppTheme.isDesktop(context)
                ? _buildDesktopBody(
                    context,
                    walletAddr,
                    wallet,
                    usdAmount,
                    eurAmount,
                    timeStr,
                  )
                : Column(
                    children: [
                      const SizedBox(height: 4),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor(context),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: AppTheme.cardShadowFor(context),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                            child: _buildReceiveFlow(
                              context,
                              walletAddr,
                              wallet,
                              usdAmount,
                              eurAmount,
                              timeStr,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    String? walletAddr,
    WalletProvider wallet,
    double usdAmount,
    double eurAmount,
    String timeStr,
  ) {
    return DesktopContent(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Receive Funds',
            subtitle:
                'Share your wallet address and prepare a clean payment request for clients',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: DesktopCardSection(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildWalletAddressCard(context, walletAddr),
                          const SizedBox(height: 16),
                          _buildAmountCard(
                            context,
                            label: 'Client pays',
                            amount: usdAmount > 0
                                ? '\$${usdAmount.toStringAsFixed(2)}'
                                : '\$0.00',
                            time: timeStr,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _softAccentColor(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildAmountCard(
                            context,
                            label: 'You receive',
                            amount: usdAmount > 0
                                ? '€${eurAmount.toStringAsFixed(2)}'
                                : '€0.00',
                            time: timeStr,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.desktopPanelGap),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      DesktopCardSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add the amount, optional reference, and quick-share actions.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            _buildAmountInput(context),
                            const SizedBox(height: 18),
                            _buildReferenceInput(context),
                            const SizedBox(height: 22),
                            _buildActionButtons(context, walletAddr),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.desktopSectionGap),
                      DesktopCardSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rates Snapshot',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildRateRow(
                              context,
                              'USD to EUR',
                              wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95',
                            ),
                            const SizedBox(height: 10),
                            _buildRateRow(
                              context,
                              'USD to GBP',
                              wallet.rates['GBP']?.toStringAsFixed(2) ?? '0.79',
                            ),
                            const SizedBox(height: 10),
                            _buildRateRow(
                                context, 'Selected currency', _currency),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveFlow(
    BuildContext context,
    String? walletAddr,
    WalletProvider wallet,
    double usdAmount,
    double eurAmount,
    String timeStr,
  ) {
    final eur = wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95';
    final gbp = wallet.rates['GBP']?.toStringAsFixed(2) ?? '0.79';

    return Column(
      children: [
        _buildWalletAddressCard(context, walletAddr),
        const SizedBox(height: 16),
        _buildAmountCard(
          context,
          label: 'Client pays',
          amount:
              usdAmount > 0 ? '\$${usdAmount.toStringAsFixed(2)}' : '\$0.00',
          time: timeStr,
        ),
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _softAccentColor(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 12),
        _buildAmountCard(
          context,
          label: 'You receive',
          amount: usdAmount > 0 ? '€${eurAmount.toStringAsFixed(2)}' : '€0.00',
          time: timeStr,
        ),
        const SizedBox(height: 20),
        Text(
          '1 USD = EUR $eur • GBP $gbp',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textTertiaryColor(context),
          ),
        ),
        const SizedBox(height: 28),
        _buildActionButtons(context, walletAddr),
        const SizedBox(height: 32),
        _buildAmountInput(context),
        const SizedBox(height: 20),
        _buildReferenceInput(context),
      ],
    );
  }

  Widget _buildRateRow(BuildContext context, String label, String value) {
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

  Widget _buildWalletAddressCard(BuildContext context, String? walletAddr) {
    return GestureDetector(
      onTap: () {
        if (walletAddr != null) {
          Clipboard.setData(ClipboardData(text: walletAddr));
          AppSnackbarService.instance.info(
            message: 'Wallet address copied',
            dedupeKey: 'receive_wallet_address_copied',
            duration: const Duration(seconds: 2),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _softSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
          border: Border.all(color: _softBorderColor(context), width: 1),
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
                  Text(
                    'Your Wallet Address',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textTertiaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortenAddress(walletAddr),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.content_copy_rounded,
                size: 18, color: AppTheme.textTertiaryColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(
    BuildContext context, {
    required String label,
    required String amount,
    required String time,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _softSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: _softBorderColor(context)),
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
                        color: AppTheme.textPrimaryColor(context)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.textPrimaryColor(context)
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.content_copy_rounded,
                        size: 16,
                        color: AppTheme.textPrimaryColor(context)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Amount
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
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
                      color: AppTheme.textPrimaryColor(context)
                          .withValues(alpha: 0.45),
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

  Widget _buildActionButtons(BuildContext context, String? walletAddr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionItem(
            context, Icons.qr_code_scanner_rounded, 'Scan QR', () {}),
        _buildActionItem(context, Icons.share_outlined, 'Share', () {
          if (walletAddr != null) {
            Clipboard.setData(ClipboardData(text: walletAddr));
            AppSnackbarService.instance.info(
              message: 'Wallet address copied to share',
              dedupeKey: 'receive_wallet_address_share_copy',
              duration: const Duration(seconds: 2),
            );
          }
        }),
        _buildActionItem(context, Icons.more_horiz_rounded, 'More', () {}),
      ],
    );
  }

  Widget _buildActionItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
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
                color:
                    AppTheme.textPrimaryColor(context).withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child:
                Icon(icon, size: 22, color: AppTheme.textPrimaryColor(context)),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: _softSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: _softBorderColor(context), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHintColor(context),
                ),
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppTheme.textPrimaryColor(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: _softSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: _softBorderColor(context), width: 1),
      ),
      child: TextField(
        controller: _referenceController,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: InputDecoration(
          labelText: 'Reference ID (optional)',
          labelStyle: TextStyle(
            fontSize: 13,
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
}
