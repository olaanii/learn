import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

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
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Fund Wallet'),
        ),
        body: Column(
          children: [
            // Tab bar
            _buildTabBar(),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFaucetTab(),
                  _buildExternalWalletTab(),
                  _buildCardPaymentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicator: BoxDecoration(
          color: AppTheme.darkButton,
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
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 1: TESTNET FAUCET
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildFaucetTab() {
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
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 24),

          // Token selector + amount
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Token',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                // Token chips
                Row(
                  children: [
                    _buildTokenChip('USDC', _selectedFaucetToken == 'USDC',
                        () {
                      setState(() => _selectedFaucetToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip('USDT', _selectedFaucetToken == 'USDT',
                        () {
                      setState(() => _selectedFaucetToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
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
                                ? AppTheme.darkButton
                                : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.darkButton
                                  : const Color(0xFFE5E7EB),
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
                                    ? Colors.white
                                    : AppTheme.textPrimary,
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
                  controller: _faucetAmountController,
                  hint: 'Custom amount (max 10,000)',
                ),
                const SizedBox(height: 8),
                Text(
                  'Max: 10,000 $_selectedFaucetToken per request',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
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
                      backgroundColor: const Color(0xFF8B5CF6),
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
            _buildResultMessage(_faucetResult!),
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

    final amount =
        double.tryParse(_faucetAmountController.text.trim()) ?? 1000;
    if (amount <= 0 || amount > 10000) {
      setState(() => _faucetResult = 'error:Amount must be between 1 and 10,000');
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadow,
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
              const Text(
                'Prerequisites',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPrerequisiteItem(
            '1',
            'CTC Gas Token',
            'Get free CTC from Creditcoin Discord #token-faucet',
          ),
          const SizedBox(height: 10),
          _buildPrerequisiteItem(
            '2',
            'Creditcoin Testnet',
            'Add network to MetaMask: RPC https://rpc.cc3-testnet.creditcoin.network, Chain ID 102031',
          ),
          const SizedBox(height: 10),
          _buildPrerequisiteItem(
            '3',
            'Sign Transaction',
            'Your wallet will prompt you to sign the faucet transaction',
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisiteItem(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.darkButton,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
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
  Widget _buildExternalWalletTab() {
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
                'Send tokens from MetaMask, Coinbase Wallet, or any EVM wallet to your Equb address below.',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),

          // Your Equb Wallet Address
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Equb Wallet Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Send TestUSDC or TestUSDT on Creditcoin Testnet to:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                // Address box
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: walletAddr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wallet address copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadiusSmall),
                      border:
                          Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap to copy full address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textTertiary,
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
                      const Text(
                        'Creditcoin Testnet (Chain 102031)',
                        style: TextStyle(
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
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transfer from External Wallet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter the sender address and amount to generate a transfer request.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                // Token selector
                Row(
                  children: [
                    _buildTokenChip(
                        'USDC', _selectedExternalToken == 'USDC', () {
                      setState(() => _selectedExternalToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip(
                        'USDT', _selectedExternalToken == 'USDT', () {
                      setState(() => _selectedExternalToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                // Sender address input
                _buildTextInput(
                  controller: _externalAddressController,
                  hint: '0x... sender wallet address',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 12),
                // Amount input
                _buildAmountInput(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Transfer transaction built! Sign it from the sender wallet.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wallet.errorMessage ?? 'Failed to build transfer'),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 3: CARD PAYMENT (SIMULATED ON-RAMP)
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildCardPaymentTab() {
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
            color: const Color(0xFF0891B2),
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
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment method logos
                Row(
                  children: [
                    _buildPaymentMethodBadge('Visa', const Color(0xFF1A1F71)),
                    const SizedBox(width: 8),
                    _buildPaymentMethodBadge(
                        'Mastercard', const Color(0xFFEB001B)),
                    const SizedBox(width: 8),
                    _buildPaymentMethodBadge(
                        'Apple Pay', AppTheme.textPrimary),
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
                              color:
                                  AppTheme.positive.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Secure',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  AppTheme.positive.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Token selector
                const Text(
                  'Buy Token',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTokenChip('USDC', _selectedCardToken == 'USDC', () {
                      setState(() => _selectedCardToken = 'USDC');
                    }),
                    const SizedBox(width: 10),
                    _buildTokenChip('USDT', _selectedCardToken == 'USDT', () {
                      setState(() => _selectedCardToken = 'USDT');
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                const Text(
                  'Amount (USD)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildAmountInput(
                  controller: _cardAmountController,
                  hint: 'Enter amount in USD',
                ),
                const SizedBox(height: 6),
                const Text(
                  '1 USD = 1 USDC (1:1 stablecoin)',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 20),

                // Card number
                const Text(
                  'Card Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextInput(
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
                          const Text(
                            'Expiry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextInput(
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
                          const Text(
                            'CVV',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextInput(
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
                  _buildPurchaseSummary(),

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
                      _cardLoading ? 'Processing...' : 'Buy $_selectedCardToken',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0891B2),
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
          _buildPartnerInfo(),
        ],
      ),
    );
  }

  Widget _buildPurchaseSummary() {
    final amountStr = _cardAmountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final fee = (amount * 0.015).clamp(0.5, 50.0); // 1.5% fee, min $0.50
    final total = amount + fee;
    final receive = amount; // 1:1 stablecoin

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          _buildSummaryRow('You pay', '\$${amount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'Processing fee (1.5%)', '\$${fee.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _buildSummaryRow(
              'Total charge', '\$${total.toStringAsFixed(2)}',
              bold: true),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'You receive',
            '${receive.toStringAsFixed(2)} $_selectedCardToken',
            bold: true,
            valueColor: AppTheme.positive,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? AppTheme.textPrimary : AppTheme.textTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? AppTheme.textPrimary,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all card details')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test purchase complete! $amount $_selectedCardToken will be credited to your wallet.',
          ),
          duration: const Duration(seconds: 3),
        ),
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

  Widget _buildPartnerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined,
              size: 20, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Card payments are processed securely. In production, this integrates with licensed on-ramp providers like MoonPay, Transak, or Ramp Network.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
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

  Widget _buildTokenChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.darkButton : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.darkButton : const Color(0xFFE5E7EB),
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
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppTheme.primaryColor,
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
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppTheme.textHint,
          ),
          prefixText: '\$ ',
          prefixStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTextInput({
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
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textHint,
          ),
          icon: Icon(icon, size: 20, color: AppTheme.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildResultMessage(String message) {
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
