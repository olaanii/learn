import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/network_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_snackbar_service.dart';
import '../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool standalone;

  const ProfileScreen({super.key, this.standalone = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _dataLoaded = false;
  bool _wcDialogShown = false;
  bool _isBindingWallet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProfileData();
      });
    }
  }

  void _loadProfileData() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final credit = context.read<CreditProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.walletAddress != null) {
      credit.loadTierEligibility(auth.walletAddress!);
      final network = context.read<NetworkProvider>();
      wallet.loadAll(auth.walletAddress!, nativeSymbol: network.nativeSymbol);
    }
  }

  String _shortenAddress(String? address) {
    if (address == null || address.length < 12) return address ?? '—';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);

    if (widget.standalone) {
      return Container(
        decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(context),
          body: body,
        ),
      );
    }

    // Embedded mode inside MainShell
    return Column(
      children: [
        // Inline header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 22),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text('Profile'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22),
          onPressed: () async {
            final auth = context.read<AuthProvider>();
            final router = GoRouter.of(context);
            await auth.logout();
            if (!mounted) return;
            router.go('/');
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer4<AuthProvider, CreditProvider, WalletProvider,
        WalletService>(
      builder: (context, auth, credit, wallet, walletService, _) {
        final walletAddr = auth.walletAddress;
        final shortAddr = _shortenAddress(walletAddr);
        final balance = wallet.balance;

        if (walletService.isConnecting &&
            walletService.pairingUri != null &&
            !_wcDialogShown) {
          _wcDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showWalletConnectDialog(context, walletService);
          });
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              _buildAvatarSection(context, walletAddr, shortAddr),
              const SizedBox(height: 24),
              _buildBalanceCard(context, balance, wallet.token),
              const SizedBox(height: 28),
              _buildAccountSection(context),
              const SizedBox(height: 24),
              _buildPreferencesSection(context),
              const SizedBox(height: 20),
              if (walletService.isConnected || AppConfig.walletConnectProjectId.isNotEmpty) ...[
                _buildWalletConnectCard(context, auth, walletService),
                const SizedBox(height: 20),
              ],
              _buildInfoCard(context, auth, credit),
              const SizedBox(height: 28),
              _buildLogOutButton(context),
              const SizedBox(height: 16),
              Text('Version 1.0.0 (Build 1)', style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarSection(BuildContext context, String? walletAddr, String shortAddr) {
    return Column(
      children: [
        SizedBox(
          width: 96, height: 96,
          child: Stack(
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.3),
                  border: Border.all(color: AppTheme.cardColor(context), width: 3),
                  boxShadow: AppTheme.cardShadowFor(context),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://i.pravatar.cc/150?img=12',
                  width: 96, height: 96, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 48, color: Colors.white70),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor,
                    border: Border.all(color: AppTheme.cardColor(context), width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            if (walletAddr != null) {
              Clipboard.setData(ClipboardData(text: walletAddr));
              AppSnackbarService.instance.info(message: 'Wallet address copied', dedupeKey: 'profile_wallet_address_copied', duration: const Duration(seconds: 2));
            }
          },
          child: Text(shortAddr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
        ),
        const SizedBox(height: 4),
        Text(
          '@$shortAddr · Diaspora Member',
          style: TextStyle(fontSize: 13, color: AppTheme.textTertiaryColor(context)),
        ),
      ],
    );
  }

  void _showWalletConnectDialog(BuildContext context, WalletService ws) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer<WalletService>(
        builder: (context, walletService, _) {
          if (!walletService.isConnecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.of(ctx).pop();
              _wcDialogShown = false;
              setState(() {});
            });
          }
          final uri = walletService.pairingUri ?? '';
          return AlertDialog(
            title: const Text('Connect Wallet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan with MetaMask or any WalletConnect-compatible wallet (${context.read<NetworkProvider>().networkName})',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (uri.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: uri,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for approval...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _wcDialogShown = false;
                  setState(() {});
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      _wcDialogShown = false;
      if (mounted) setState(() {});
    });
  }

  Widget _buildWalletConnectCard(
      BuildContext context, AuthProvider auth, WalletService walletService) {
    final hasProjectId = AppConfig.walletConnectProjectId.isNotEmpty;

    if (!hasProjectId) {
      return Container(
        width: double.infinity,
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
                Icon(Icons.link_off_rounded,
                    size: 22, color: AppTheme.textTertiaryColor(context)),
                const SizedBox(width: 10),
                Text(
                  'WalletConnect',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set WALLETCONNECT_PROJECT_ID (from cloud.walletconnect.com) via --dart-define to enable wallet signing on ${context.read<NetworkProvider>().networkName}.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
        ),
      );
    }

    final connected = walletService.isConnected;
    final wcAddress = walletService.walletAddress;
    final boundAddress = auth.walletAddress;
    final canBind = connected && wcAddress != null && wcAddress != boundAddress;

    return Container(
      width: double.infinity,
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
              Icon(
                connected
                    ? Icons.account_balance_wallet_rounded
                    : Icons.link_rounded,
                size: 22,
                color: connected ? AppTheme.positive : AppTheme.textTertiaryColor(context),
              ),
              const SizedBox(width: 10),
              Text(
                'WalletConnect (${context.read<NetworkProvider>().shortNetworkName})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            connected
                ? 'Connected: ${_shortenAddress(wcAddress)}'
                : 'Connect your wallet to sign equb, collateral and transfer transactions on ${context.read<NetworkProvider>().networkName}.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          if ((walletService.errorMessage ?? auth.errorMessage) != null) ...[
            const SizedBox(height: 8),
            Text(
              walletService.errorMessage ?? auth.errorMessage ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.negative,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (connected) ...[
                OutlinedButton.icon(
                  onPressed: _isBindingWallet
                      ? null
                      : () async {
                          if (wcAddress == null) return;
                          setState(() => _isBindingWallet = true);
                          await auth.bindWallet(wcAddress);
                          setState(() => _isBindingWallet = false);
                          if (mounted) {
                            AppSnackbarService.instance.success(
                              message:
                                  'Wallet bound. App will use this address.',
                              dedupeKey: 'profile_wallet_bind_success',
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                  icon: _isBindingWallet
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                      canBind ? 'Use this wallet in app' : 'Already in use'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () async {
                    await walletService.disconnect();
                    if (mounted) setState(() {});
                  },
                  child: const Text('Disconnect'),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: (walletService.isConnecting ||
                          auth.status == AuthStatus.loading)
                      ? null
                      : () async {
                          await auth.loginWithWalletOnly();
                          if (mounted) setState(() {});
                        },
                  icon: (walletService.isConnecting ||
                          auth.status == AuthStatus.loading)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(
                    walletService.isConnecting
                        ? 'Connecting...'
                        : (auth.status == AuthStatus.loading
                            ? 'Sign in wallet...'
                            : 'Connect wallet'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, String balance, String token) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryColor(context))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.currency_exchange_rounded, size: 18, color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$$balance', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryColor(context), letterSpacing: -1)),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 16, color: AppTheme.positive),
              SizedBox(width: 4),
              Text('+\$0.00 (0%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.positive)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => context.push('/fund'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor(context),
                      foregroundColor: AppTheme.buttonTextColor(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Top Up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => context.push('/withdraw'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimaryColor(context),
                      side: BorderSide(color: AppTheme.textHintColor(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Withdraw', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('ACCOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.textTertiaryColor(context))),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: Column(
            children: [
              _buildAccountRow(context, Icons.person_outline_rounded, AppTheme.secondaryColor, 'Personal Info', 'Name, email, phone', onTap: () {}),
              Divider(height: 1, indent: 60, color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildAccountRow(context, Icons.groups_outlined, AppTheme.primaryColor, 'Equb Groups', 'Manage your circles', onTap: () => context.push('/pools')),
              Divider(height: 1, indent: 60, color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildAccountRow(context, Icons.shield_outlined, AppTheme.positive, 'Security', 'Password, 2FA, FaceID', onTap: () => context.push('/collateral')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRow(BuildContext context, IconData icon, Color iconColor, String title, String subtitle, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.textTertiaryColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('PREFERENCES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.textTertiaryColor(context))),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.subtleShadowFor(context),
          ),
          child: Column(
            children: [
              _buildPreferenceRow(
                context,
                Icons.notifications_none_rounded,
                AppTheme.accentYellow,
                'Notifications',
                trailing: Switch.adaptive(
                  value: false,
                  onChanged: (_) {},
                  activeThumbColor: AppTheme.positive,
                  activeTrackColor: AppTheme.positive.withValues(alpha: 0.45),
                ),
              ),
              Divider(height: 1, indent: 60, color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(context, Icons.dark_mode_outlined, AppTheme.primaryColor, 'Dark Mode', trailing: Switch.adaptive(value: themeProvider.isDark, onChanged: (_) => themeProvider.toggleDarkMode(), activeThumbColor: AppTheme.accentYellow, activeTrackColor: AppTheme.secondaryColor)),
              Divider(height: 1, indent: 60, color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(context, Icons.help_outline_rounded, AppTheme.secondaryColor, 'Help & Support', trailing: Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.textTertiaryColor(context)), onTap: () {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceRow(BuildContext context, IconData icon, Color iconColor, String title, {Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          final auth = context.read<AuthProvider>();
          final router = GoRouter.of(context);
          await auth.logout();
          if (!mounted) return;
          router.go('/');
        },
        icon: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.negative),
        label: const Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.negative)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.negative.withValues(alpha: 0.3)),
          backgroundColor: AppTheme.negative.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, AuthProvider auth, CreditProvider credit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        children: [
          _buildInfoRow(context, 'Identity', _shortenAddress(auth.identityHash)),
          const Divider(height: 20),
          _buildInfoRow(context, 'Eligible Tier', 'Tier ${credit.eligibleTier}'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Collateral Rate', '${credit.collateralRate / 100}%'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Max Equb Size', '\$${credit.maxPoolSize}'),
          if (credit.nextTier != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Next Tier',
              'Tier ${credit.nextTier} (need ${credit.scoreForNextTier} pts)',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiaryColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

}
