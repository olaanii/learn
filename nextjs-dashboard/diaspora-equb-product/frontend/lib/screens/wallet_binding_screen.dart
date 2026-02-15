import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../config/theme.dart';
import '../config/app_config.dart';

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
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Connect Your Wallet'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity confirmed card
                Card(
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
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hash: ${auth.identityHash != null && auth.identityHash!.length >= 16 ? auth.identityHash!.substring(0, 16) : auth.identityHash ?? ''}...',
                                style: TextStyle(
                                  color: Colors.grey[700],
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
                ),
                const SizedBox(height: 32),

                // Step indicator
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
                  'Connect your EVM wallet to your Fayda identity via WalletConnect. '
                  'This creates a one-to-one binding that enables non-custodial transactions.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // ── WalletConnect Button ──
                if (AppConfig.walletConnectProjectId.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: wallet.isConnecting || _isBinding
                        ? null
                        : () async {
                            setState(() => _isBinding = true);
                            await auth.connectAndBindWallet();
                            setState(() => _isBinding = false);
                          },
                    icon: wallet.isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.account_balance_wallet),
                    label: Text(wallet.isConnecting
                        ? 'Connecting...'
                        : 'Connect with WalletConnect'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  // Show pairing URI as QR code when connecting
                  if (wallet.pairingUri != null &&
                      wallet.pairingUri!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'Scan with your wallet (Creditcoin Testnet)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView(
                                data: wallet.pairingUri!,
                                version: QrVersions.auto,
                                size: 220,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Waiting for wallet approval...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showManualEntry = !_showManualEntry),
                    child: Text(_showManualEntry
                        ? 'Hide manual entry'
                        : 'Enter address manually instead'),
                  ),
                ],

                // ── Manual Address Entry (fallback / dev) ──
                if (_showManualEntry ||
                    AppConfig.walletConnectProjectId.isEmpty) ...[
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
                            if (!RegExp(r'^0x[a-fA-F0-9]{40}$')
                                .hasMatch(value)) {
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
                                    await auth.bindWallet(
                                        _walletController.text.trim());
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

                // Info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text('Non-Custodial',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your private keys never leave your wallet. '
                          'The backend only builds unsigned transactions for you to approve. '
                          'All pool contributions and payouts are executed on-chain.',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
