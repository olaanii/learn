import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/device_identity_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _totpCodeController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _qrUri;
  String? _secret;
  String? _error;
  String? _currentFingerprint;
  List<dynamic> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _totpCodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasBoundWallet) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final deviceIdentity = context.read<DeviceIdentityService>();
      final fingerprint = await deviceIdentity.getOrCreateFingerprint();
      final deviceLabel = await deviceIdentity.currentLabel();
      await api.registerTrustedDevice(
        fingerprint: fingerprint,
        userAgent: deviceLabel,
      );
      final status = await api.get2FAStatus();
      final devices = await api.listTrustedDevices();
      final biometricEnabled = await BiometricService.isEnabled;
      final biometricAvailable = await BiometricService.isAvailable();

      if (!mounted) return;
      setState(() {
        _twoFactorEnabled = status['enabled'] == true;
        _devices = devices;
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
        _currentFingerprint = fingerprint;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load security settings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _setup2FA() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await context.read<ApiClient>().setup2FA();
      if (!mounted) return;
      setState(() {
        _secret = result['secret'] as String?;
        _qrUri = result['qrUri'] as String?;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to set up 2FA: $e';
        _saving = false;
      });
    }
  }

  Future<void> _verify2FA() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<ApiClient>()
          .verify2FA(_totpCodeController.text.trim());
      if (!mounted) return;
      setState(() {
        _twoFactorEnabled = true;
        _qrUri = null;
        _secret = null;
        _totpCodeController.clear();
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '2FA verification failed: $e';
        _saving = false;
      });
    }
  }

  Future<void> _disable2FA() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().disable2FA();
      if (!mounted) return;
      setState(() {
        _twoFactorEnabled = false;
        _qrUri = null;
        _secret = null;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to disable 2FA: $e';
        _saving = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final success = await BiometricService.authenticate();
      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = 'Biometric authentication was not completed.';
        });
        return;
      }
    }

    await BiometricService.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _biometricEnabled = value;
    });
  }

  Future<void> _revokeDevice(String deviceId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().revokeTrustedDevice(deviceId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to revoke device: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trustedDeviceCount = _devices.length;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Security')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _buildSecurityOverviewCard(
                      context,
                      hasBoundWallet: auth.hasBoundWallet,
                      trustedDeviceCount: trustedDeviceCount,
                    ),
                    const SizedBox(height: 16),
                    if (!auth.hasBoundWallet)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connect a wallet to unlock full security controls',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '2FA, trusted devices, and transaction security are tied to the wallet linked to your account.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _buildSectionCard(
                        context,
                        title: 'Authenticator app 2FA',
                        subtitle: _twoFactorEnabled
                            ? 'Two-factor authentication is active for your bound wallet.'
                            : 'Add a TOTP app such as Google Authenticator or 1Password.',
                        trailing: _twoFactorEnabled
                            ? OutlinedButton(
                                onPressed: _saving ? null : _disable2FA,
                                child: const Text('Disable'),
                              )
                            : ElevatedButton(
                                onPressed: _saving ? null : _setup2FA,
                                child: const Text('Set up 2FA'),
                              ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_qrUri != null) ...[
                              const SizedBox(height: 14),
                              Center(
                                child: QrImageView(
                                  data: _qrUri!,
                                  size: 180,
                                  version: QrVersions.auto,
                                ),
                              ),
                              if (_secret != null) ...[
                                const SizedBox(height: 12),
                                SelectableText(
                                  'Secret: $_secret',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 14),
                              TextField(
                                controller: _totpCodeController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '6-digit code',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _saving ? null : _verify2FA,
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Verify and enable'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        context,
                        title: 'Biometric unlock',
                        subtitle: _biometricAvailable
                            ? 'Use the device biometric prompt before sensitive actions.'
                            : 'Biometric unlock is not available on this device.',
                        trailing: Switch.adaptive(
                          value: _biometricEnabled,
                          onChanged:
                              _biometricAvailable ? _toggleBiometric : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        context,
                        title: 'Transaction confirmation',
                        subtitle:
                            'Require an extra confirmation step before wallet-sensitive actions.',
                        trailing: Switch.adaptive(
                          value: auth.requireTransactionConfirmation,
                          onChanged:
                              auth.updateTransactionConfirmationPreference,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        context,
                        title: 'Trusted devices',
                        subtitle:
                            'Revoke devices that should no longer be trusted.',
                        child: Column(
                          children: _devices.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      'No trusted devices recorded yet.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ]
                              : _devices.map((device) {
                                  final userAgent =
                                      device['userAgent']?.toString() ??
                                          'Unknown device';
                                  final lastSeen =
                                      device['lastSeen']?.toString() ??
                                          'Unknown';
                                  final deviceId =
                                      device['id']?.toString() ?? '';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading:
                                        const Icon(Icons.devices_other_rounded),
                                    title: Text(userAgent),
                                    subtitle: Text(
                                      device['fingerprint']?.toString() ==
                                              _currentFingerprint
                                          ? 'Current device · Last seen: $lastSeen'
                                          : 'Last seen: $lastSeen',
                                    ),
                                    trailing: TextButton(
                                      onPressed: _saving || deviceId.isEmpty
                                          ? null
                                          : () => _revokeDevice(deviceId),
                                      child: const Text('Revoke'),
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.negative),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    Widget? trailing,
    Widget? child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ],
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOverviewCard(
    BuildContext context, {
    required bool hasBoundWallet,
    required int trustedDeviceCount,
  }) {
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account protection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasBoundWallet
                          ? 'Security controls are anchored to your bound wallet and trusted devices.'
                          : 'Bind one wallet first to unlock full security coverage across 2FA and device trust.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOverviewChip(
                context,
                icon: hasBoundWallet ? Icons.verified_user : Icons.link_off,
                label: hasBoundWallet ? 'Wallet bound' : 'Wallet not bound',
                color:
                    hasBoundWallet ? AppTheme.positive : AppTheme.warningColor,
              ),
              _buildOverviewChip(
                context,
                icon: _twoFactorEnabled
                    ? Icons.password
                    : Icons.password_outlined,
                label: _twoFactorEnabled ? '2FA enabled' : '2FA available',
                color: _twoFactorEnabled
                    ? AppTheme.positive
                    : AppTheme.primaryColor,
              ),
              _buildOverviewChip(
                context,
                icon: _biometricEnabled
                    ? Icons.fingerprint
                    : Icons.fingerprint_outlined,
                label:
                    _biometricEnabled ? 'Biometric on' : 'Biometric optional',
                color: _biometricEnabled
                    ? AppTheme.positive
                    : AppTheme.primaryColor,
              ),
              _buildOverviewChip(
                context,
                icon: Icons.devices_other_outlined,
                label:
                    '$trustedDeviceCount trusted ${trustedDeviceCount == 1 ? 'device' : 'devices'}',
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
