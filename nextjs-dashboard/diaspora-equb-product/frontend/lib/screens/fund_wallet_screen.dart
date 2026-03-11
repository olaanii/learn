import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/network_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
import '../widgets/desktop_layout.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Faucet fields
  String _selectedFaucetToken = 'USDC';
  final _faucetAmountController = TextEditingController(text: '1000');
  bool _faucetLoading = false;
  String? _faucetResult;

  // External wallet fields
  final _externalAddressController = TextEditingController();
  final _externalAmountController = TextEditingController();
  String _selectedExternalToken = 'USDC';

  // Card payment fields
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardAmountController = TextEditingController();
  String _selectedCardToken = 'USDC';
  bool _cardLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _faucetAmountController.dispose();
    _externalAddressController.dispose();
    _externalAmountController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardAmountController.dispose();
    super.dispose();
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
          title: const Text('Fund Wallet'),
        ),
        body: AppTheme.isDesktop(context)
            ? _buildDesktopBody(context)
            : Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFaucetTab(context),
                        _buildExternalWalletTab(context),
                        _buildCardPaymentTab(context),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return DesktopContent(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Wallet Funding',
            subtitle:
                'Move test assets in with faucet, external wallet, or card simulation',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: DesktopCardSection(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Column(
                      children: [
                        _buildTabBar(),
                        const SizedBox(height: 18),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFaucetTab(context),
                              _buildExternalWalletTab(context),
                              _buildCardPaymentTab(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.desktopPanelGap),
                Expanded(
                  flex: 4,
                  child: _buildDesktopFundingSidebar(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFundingSidebar(BuildContext context) {
    final network = context.watch<NetworkProvider>();
    final auth = context.watch<AuthProvider>();
    final walletAddress = auth.walletAddress;
    final shortAddress = walletAddress == null
        ? 'No wallet connected'
        : walletAddress.length > 14
            ? '${walletAddress.substring(0, 8)}...${walletAddress.substring(walletAddress.length - 6)}'
            : walletAddress;

    return Column(
      children: [
        DesktopCardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Funding Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Use the method that matches your testnet flow.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              _buildDesktopSummaryRow(
                  context, 'Active network', network.networkName),
              const SizedBox(height: 10),
              _buildDesktopSummaryRow(
                  context, 'Chain ID', network.chainId.toString()),
              const SizedBox(height: 10),
              _buildDesktopSummaryRow(context, 'Wallet', shortAddress),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.desktopSectionGap),
        DesktopCardSection(child: _buildPrerequisiteCard()),
        const SizedBox(height: AppTheme.desktopSectionGap),
        DesktopCardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Methods',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildMethodHint(context, Icons.science_outlined, 'Test Faucet',
                  'Fastest way to mint dev tokens.'),
              const SizedBox(height: 10),
              _buildMethodHint(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'External Wallet',
                  'Generate a transfer from another EVM wallet.'),
              const SizedBox(height: 10),
              _buildMethodHint(context, Icons.credit_card_rounded, 'Card',
                  'Simulated on-ramp for desktop demos.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSummaryRow(
      BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiaryColor(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodHint(
      BuildContext context, IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.buttonColor(context).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.buttonColor(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Builder(
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.buttonTextColor(context),
            unselectedLabelColor: AppTheme.textSecondaryColor(context),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            indicator: BoxDecoration(
              color: AppTheme.buttonColor(context),
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: const [
              Tab(text: 'Test Faucet'),
              Tab(text: 'Wallet'),
              Tab(text: 'Card'),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 1: TESTNET FAUCET
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildFaucetTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          _buildInfoBanner(
            icon: Icons.science_outlined,
            title: 'Testnet Faucet',
            subtitle:
                'Mint free test tokens to your wallet. These are testnet tokens for development only — no real value.',
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 24),

          // Token selector + amount
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Token',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                // Token chips
                Row(
                  children: [
                    _buildTokenChip(
                        context, 'USDC', _selectedFaucetToken == 'USDC', () {
                      setState(() => _selectedFaucetToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip(
                        context, 'USDT', _selectedFaucetToken == 'USDT', () {
                      setState(() => _selectedFaucetToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                // Quick amount buttons
                Row(
                  children: [100, 500, 1000, 5000, 10000].map((amt) {
                    final isSelected =
                        _faucetAmountController.text == amt.toString();
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _faucetAmountController.text = amt.toString();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.buttonColor(context)
                                : AppTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.buttonColor(context)
                                  : AppTheme.textHint,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _formatQuickAmount(amt),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.buttonTextColor(context)
                                    : AppTheme.textPrimaryColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Custom amount input
                _buildAmountInput(
                  context: context,
                  controller: _faucetAmountController,
                  hint: 'Custom amount (max 10,000)',
                ),
                const SizedBox(height: 8),
                Text(
                  'Max: 10,000 $_selectedFaucetToken per request',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 20),
                // Mint button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _faucetLoading ? null : _handleFaucetRequest,
                    icon: _faucetLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.water_drop_outlined, size: 20),
                    label: Text(
                      _faucetLoading
                          ? 'Requesting...'
                          : 'Get Free $_selectedFaucetToken',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Result message
          if (_faucetResult != null) ...[
            const SizedBox(height: 16),
            _buildResultMessage(context, _faucetResult!),
          ],

          const SizedBox(height: 24),

          // Prerequisites
          _buildPrerequisiteCard(),
        ],
      ),
    );
  }

  String _formatQuickAmount(int amt) {
    if (amt >= 1000) return '${amt ~/ 1000}K';
    return amt.toString();
  }

  Future<void> _handleFaucetRequest() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress == null) {
      setState(() => _faucetResult = 'error:No wallet connected');
      return;
    }

    final amount = double.tryParse(_faucetAmountController.text.trim()) ?? 1000;
    if (amount <= 0 || amount > 10000) {
      setState(
          () => _faucetResult = 'error:Amount must be between 1 and 10,000');
      return;
    }

    setState(() {
      _faucetLoading = true;
      _faucetResult = null;
    });

    final result = await wallet.requestFaucet(
      walletAddress: auth.walletAddress!,
      amount: amount,
      token: _selectedFaucetToken,
    );

    if (!mounted) return;

    if (result != null) {
      final txHash = result['txHash'] as String? ?? '';
      final shortHash = txHash.length > 14
          ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 4)}'
          : txHash;
      setState(() {
        _faucetLoading = false;
        _faucetResult = txHash.isNotEmpty
            ? 'success:${amount.toStringAsFixed(0)} $_selectedFaucetToken minted to your wallet! Tx: $shortHash'
            : 'success:${result['message'] ?? 'Tokens minted successfully!'}';
      });
      // Refresh balance after confirmation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && auth.walletAddress != null) {
          wallet.loadBalance(auth.walletAddress!);
        }
      });
    } else {
      setState(() {
        _faucetLoading = false;
        _faucetResult =
            'error:${wallet.errorMessage ?? "Failed to request faucet tokens"}';
      });
    }
  }

  Widget _buildPrerequisiteCard() {
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline,
                        size: 16, color: AppTheme.warningColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Prerequisites',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final network = context.read<NetworkProvider>();
                final sym = network.nativeSymbol;
                return Column(children: [
                  _buildPrerequisiteItem(
                    context,
                    '1',
                    '$sym Gas Token',
                    'Get free $sym from Creditcoin Discord #token-faucet',
                  ),
                  const SizedBox(height: 10),
                  _buildPrerequisiteItem(
                    context,
                    '2',
                    network.networkName,
                    'Add this network to your wallet app: RPC ${network.rpcUrl}, Chain ID ${network.chainId}',
                  ),
                ]);
              }),
              const SizedBox(height: 10),
              _buildPrerequisiteItem(
                context,
                '3',
                'Sign Transaction',
                'Your wallet will prompt you to sign the faucet transaction',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrerequisiteItem(
      BuildContext context, String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.buttonColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.buttonTextColor(context),
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
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 2: EXTERNAL WALLET
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildExternalWalletTab(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final walletAddr = auth.walletAddress ?? '0x...';
    final shortAddr = walletAddr.length > 14
        ? '${walletAddr.substring(0, 8)}...${walletAddr.substring(walletAddr.length - 6)}'
        : walletAddr;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Receive from Wallet',
            subtitle:
                'Send tokens from any EVM wallet (including Coinbase Wallet) to your Equb address below.',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),

          // Your Equb Wallet Address
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Equb Wallet Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send TestUSDC or TestUSDT on ${context.read<NetworkProvider>().networkName} to:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 16),
                // Address box
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: walletAddr));
                    AppSnackbarService.instance.info(
                      message: 'Wallet address copied!',
                      dedupeKey: 'fund_wallet_address_copied',
                      duration: const Duration(seconds: 2),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadiusSmall),
                      border: Border.all(color: AppTheme.textHint, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet,
                              size: 18, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shortAddr,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor(context),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to copy full address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textTertiaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.copy_rounded,
                              size: 18, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Network badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.positive.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.positive.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.positive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${context.read<NetworkProvider>().networkName} (Chain ${context.read<NetworkProvider>().chainId})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.positive,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Send from external wallet
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer from External Wallet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the sender address and amount to generate a transfer request.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 16),
                // Token selector
                Row(
                  children: [
                    _buildTokenChip(
                        context, 'USDC', _selectedExternalToken == 'USDC', () {
                      setState(() => _selectedExternalToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip(
                        context, 'USDT', _selectedExternalToken == 'USDT', () {
                      setState(() => _selectedExternalToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                // Sender address input
                _buildTextInput(
                  context: context,
                  controller: _externalAddressController,
                  hint: '0x... sender wallet address',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 12),
                // Amount input
                _buildAmountInput(
                  context: context,
                  controller: _externalAmountController,
                  hint: 'Amount to transfer',
                ),
                const SizedBox(height: 18),
                // Generate transfer button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _handleExternalTransfer,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                    label: const Text(
                      'Generate Transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
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

  Future<void> _handleExternalTransfer() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    final from = _externalAddressController.text.trim();
    final amount = _externalAmountController.text.trim();

    if (from.isEmpty || amount.isEmpty) {
      AppSnackbarService.instance.error(
        message: 'Please fill in all fields',
        dedupeKey: 'fund_wallet_external_missing_fields',
      );
      return;
    }

    if (auth.walletAddress == null) return;

    final result = await wallet.buildTransfer(
      from: from,
      to: auth.walletAddress!,
      amount: amount,
      token: _selectedExternalToken,
    );

    if (!mounted) return;

    if (result != null) {
      AppSnackbarService.instance.success(
        message: 'Transfer transaction built! Sign it from the sender wallet.',
        dedupeKey: 'fund_wallet_external_transfer_built',
        duration: const Duration(seconds: 3),
      );
    } else {
      AppSnackbarService.instance.error(
        message: wallet.errorMessage ?? 'Failed to build transfer',
        dedupeKey: 'fund_wallet_external_transfer_failed',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 3: CARD PAYMENT (SIMULATED ON-RAMP)
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildCardPaymentTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: Icons.credit_card_rounded,
            title: 'Buy with Card',
            subtitle:
                'Purchase stablecoins with Visa or Mastercard. Powered by our on-ramp partner.',
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 8),
          // Test mode badge
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warningColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bug_report_outlined,
                    size: 14,
                    color: AppTheme.warningColor.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text(
                  'Test Mode — No real charges',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Card payment form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment method logos
                Row(
                  children: [
                    _buildPaymentMethodBadge('Visa', AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    _buildPaymentMethodBadge(
                        'Mastercard', AppTheme.dangerColor),
                    const SizedBox(width: 8),
                    _buildPaymentMethodBadge(
                        'Apple Pay', AppTheme.textPrimaryColor(context)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.positive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 12,
                              color: AppTheme.positive.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Secure',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.positive.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Token selector
                Text(
                  'Buy Token',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTokenChip(
                        context, 'USDC', _selectedCardToken == 'USDC', () {
                      setState(() => _selectedCardToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip(
                        context, 'USDT', _selectedCardToken == 'USDT', () {
                      setState(() => _selectedCardToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                Text(
                  'Amount (USD)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAmountInput(
                  context: context,
                  controller: _cardAmountController,
                  hint: 'Enter amount in USD',
                ),
                const SizedBox(height: 6),
                Text(
                  '1 USD = 1 USDC (1:1 stablecoin)',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textTertiaryColor(context)),
                ),
                const SizedBox(height: 20),

                // Card number
                Text(
                  'Card Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextInput(
                  context: context,
                  controller: _cardNumberController,
                  hint: '4242 4242 4242 4242',
                  icon: Icons.credit_card_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    _CardNumberFormatter(),
                  ],
                ),
                const SizedBox(height: 16),

                // Expiry + CVV row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expiry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            context: context,
                            controller: _cardExpiryController,
                            hint: 'MM/YY',
                            icon: Icons.calendar_today_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _ExpiryDateFormatter(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CVV',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            context: context,
                            controller: _cardCvvController,
                            hint: '123',
                            icon: Icons.security_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            obscure: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Purchase summary
                if (_cardAmountController.text.isNotEmpty)
                  _buildPurchaseSummary(context),

                // Buy button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _cardLoading ? null : _handleCardPayment,
                    icon: _cardLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_cart_checkout_rounded,
                            size: 20),
                    label: Text(
                      _cardLoading
                          ? 'Processing...'
                          : 'Buy $_selectedCardToken',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Partner info
          _buildPartnerInfo(context),
        ],
      ),
    );
  }

  Widget _buildPurchaseSummary(BuildContext context) {
    final amountStr = _cardAmountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final fee = (amount * 0.015).clamp(0.5, 50.0); // 1.5% fee, min $0.50
    final total = amount + fee;
    final receive = amount; // 1:1 stablecoin

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.textHint, width: 1),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
              context, 'You pay', '\$${amount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(
              context, 'Processing fee (1.5%)', '\$${fee.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppTheme.textHint),
          ),
          _buildSummaryRow(
              context, 'Total charge', '\$${total.toStringAsFixed(2)}',
              bold: true),
          const SizedBox(height: 8),
          _buildSummaryRow(
            context,
            'You receive',
            '${receive.toStringAsFixed(2)} $_selectedCardToken',
            bold: true,
            valueColor: AppTheme.positive,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold
                ? AppTheme.textPrimaryColor(context)
                : AppTheme.textTertiaryColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCardPayment() async {
    final amount = _cardAmountController.text.trim();
    final cardNum = _cardNumberController.text.replaceAll(' ', '');
    final expiry = _cardExpiryController.text.trim();
    final cvv = _cardCvvController.text.trim();

    if (amount.isEmpty || cardNum.isEmpty || expiry.isEmpty || cvv.isEmpty) {
      AppSnackbarService.instance.error(
        message: 'Please fill in all card details',
        dedupeKey: 'fund_wallet_card_missing_fields',
      );
      return;
    }

    setState(() => _cardLoading = true);

    // Simulate payment processing (in production: Moonpay/Transak/Ramp API)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // In test mode, trigger faucet with the same amount
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      final faucetAmount =
          (double.tryParse(amount) ?? 100).clamp(1, 10000).toDouble();
      await wallet.requestFaucet(
        walletAddress: auth.walletAddress!,
        amount: faucetAmount,
        token: _selectedCardToken,
      );
    }

    setState(() => _cardLoading = false);

    if (mounted) {
      AppSnackbarService.instance.success(
        message:
            'Test purchase complete! $amount $_selectedCardToken will be credited to your wallet.',
        dedupeKey:
            'fund_wallet_card_purchase_success_$amount$_selectedCardToken',
        duration: const Duration(seconds: 3),
      );
      // Refresh balance
      if (auth.walletAddress != null) {
        await wallet.loadBalance(auth.walletAddress!);
      }
    }
  }

  Widget _buildPaymentMethodBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPartnerInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined,
              size: 20,
              color:
                  AppTheme.textTertiaryColor(context).withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Card payments are processed securely. In production, this integrates with licensed on-ramp providers like MoonPay, Transak, or Ramp Network.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiaryColor(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenChip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.buttonColor(context)
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.buttonColor(context) : AppTheme.textHint,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.buttonTextColor(context).withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppTheme.buttonTextColor(context)
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.buttonTextColor(context)
                    : AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: AppTheme.textHint, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 16,
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
    );
  }

  Widget _buildTextInput({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: AppTheme.textHintColor(context), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textHintColor(context),
          ),
          icon:
              Icon(icon, size: 20, color: AppTheme.textTertiaryColor(context)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildResultMessage(BuildContext context, String message) {
    final isError = message.startsWith('error:');
    final text = message.replaceFirst(RegExp(r'^(error|success):'), '');
    final color = isError ? AppTheme.negative : AppTheme.positive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input formatters ──────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
