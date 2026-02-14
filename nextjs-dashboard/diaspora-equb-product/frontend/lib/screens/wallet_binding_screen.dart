import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class WalletBindingScreen extends StatefulWidget {
  const WalletBindingScreen({super.key});

  @override
  State<WalletBindingScreen> createState() => _WalletBindingScreenState();
}

class _WalletBindingScreenState extends State<WalletBindingScreen> {
  final _walletController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isBinding = false;

  @override
  void dispose() {
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Bind Your Wallet'),
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
                'Link your EVM wallet to your Fayda identity. '
                'This creates a one-to-one binding that cannot be changed.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Wallet address form
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
                    if (auth.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: AppTheme.dangerColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton.icon(
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
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.link),
                      label: const Text('Bind Wallet'),
                    ),
                  ],
                ),
              ),
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
                          Text('Important',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your wallet binding is permanent and will be stored on-chain. '
                        'Each Fayda identity can only be linked to one wallet address.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
