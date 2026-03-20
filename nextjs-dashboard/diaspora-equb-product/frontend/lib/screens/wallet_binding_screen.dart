import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/network_provider.dart';
import '../services/wallet_service.dart';
import '../config/theme.dart';
import '../widgets/desktop_layout.dart';

class WalletBindingScreen extends StatefulWidget {
  const WalletBindingScreen({super.key});

  @override
  State<WalletBindingScreen> createState() => _WalletBindingScreenState();
}

class _WalletBindingScreenState extends State<WalletBindingScreen> {
  final _walletController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isBinding = false;
  bool _showManualEntry = false;

  @override
  void dispose() {
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletService>();

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Connect Your Wallet'),
        ),
        body: SafeArea(
          child: AppTheme.isDesktop(context)
              ? _buildDesktopBody(context, auth, wallet)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildMobileContent(context, auth, wallet),
                ),
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
      BuildContext context, AuthProvider auth, WalletService wallet) {
    return DesktopContent(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSectionTitle(
            title: 'Wallet Binding',
            subtitle:
                'Bind one verified identity to one Privy wallet or enter an address manually',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: SingleChildScrollView(
                    child: DesktopCardSection(
                      child: _buildMobileContent(context, auth, wallet),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.desktopPanelGap),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      DesktopCardSection(
                          child: _buildIdentityCard(context, auth)),
                      const SizedBox(height: AppTheme.desktopSectionGap),
                      DesktopCardSection(child: _buildInfoCard(context)),
                      const SizedBox(height: AppTheme.desktopSectionGap),
                      DesktopCardSection(
                          child: _buildDesktopBindingNotes(context)),
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

  Widget _buildMobileContent(
      BuildContext context, AuthProvider auth, WalletService wallet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIdentityCard(context, auth),
        const SizedBox(height: 32),
        const Text(
          'Step 2 of 2',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect Your Wallet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create or restore your Privy embedded wallet, then bind it to your Fayda identity. '
          'You can still enter an address manually for admin or recovery flows.',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
        const SizedBox(height: 32),
        if (wallet.isSupportedPlatform && wallet.hasPrivyConfiguration) ...[
          ElevatedButton.icon(
            onPressed: wallet.isConnecting || _isBinding
                ? null
                : () async {
                    setState(() => _isBinding = true);
                    await auth.connectAndBindWallet();
                    setState(() => _isBinding = false);
                  },
            icon: wallet.isConnecting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.buttonTextColor(context),
                    ),
                  )
                : const Icon(Icons.account_balance_wallet),
            label: Text(wallet.isConnecting
                ? 'Connecting...'
                : 'Connect Privy Wallet'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                setState(() => _showManualEntry = !_showManualEntry),
            child: Text(_showManualEntry
                ? 'Hide manual entry'
                : 'Enter address manually instead'),
          ),
        ] else ...[
          Text(
            wallet.isSupportedPlatform
                ? 'Add PRIVY_APP_ID and PRIVY_APP_CLIENT_ID to enable embedded wallets in this build.'
                : 'Privy embedded wallets are only available on Android and iOS. Use manual entry on this platform.',
            style: TextStyle(color: AppTheme.textSecondaryColor(context)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _showManualEntry = true),
            child: const Text('Enter address manually instead'),
          ),
        ],
        if (_showManualEntry ||
            !wallet.isSupportedPlatform ||
            !wallet.hasPrivyConfiguration) ...[
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _walletController,
                  decoration: const InputDecoration(
                    labelText: 'Wallet Address',
                    hintText: '0x...',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your wallet address';
                    }
                    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value)) {
                      return 'Invalid EVM wallet address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isBinding
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isBinding = true);
                            await auth
                                .bindWallet(_walletController.text.trim());
                            setState(() => _isBinding = false);
                          }
                        },
                  icon: _isBinding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Bind Wallet (Manual)'),
                ),
              ],
            ),
          ),
        ],
        if (auth.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            auth.errorMessage!,
            style: const TextStyle(color: AppTheme.dangerColor),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        _buildInfoCard(context),
      ],
    );
  }

  Widget _buildIdentityCard(BuildContext context, AuthProvider auth) {
    final hash = auth.identityHash ?? '';
    final shortHash = hash.isNotEmpty && hash.length >= 16
        ? '${hash.substring(0, 16)}...'
        : hash;

    return Card(
      color: AppTheme.successColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppTheme.successColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identity Verified',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hash: $shortHash',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Non-Custodial',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your private keys never leave your wallet. '
              'The backend only builds unsigned transactions for you to approve. '
              'All equb contributions and payouts are executed on-chain.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBindingNotes(BuildContext context) {
    final network = context.watch<NetworkProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Binding Notes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildNoteRow(context, 'Target network', network.networkName),
        const SizedBox(height: 10),
        _buildNoteRow(context, 'Privy',
          context.watch<WalletService>().hasPrivyConfiguration ? 'Configured' : 'Disabled'),
        const SizedBox(height: 10),
        _buildNoteRow(
            context, 'Binding model', 'One verified identity to one wallet'),
      ],
    );
  }

  Widget _buildNoteRow(BuildContext context, String label, String value) {
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
}
