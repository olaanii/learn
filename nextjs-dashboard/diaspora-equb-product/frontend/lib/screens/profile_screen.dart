import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/equb_insights_provider.dart';
import '../providers/network_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/app_snackbar_service.dart';
import '../services/profile_preferences_service.dart';
import '../services/wallet_service.dart';
import '../widgets/desktop_layout.dart';

class ProfileScreen extends StatefulWidget {
  final bool standalone;

  const ProfileScreen({super.key, this.standalone = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _lastLoadedWallet;

  void _loadProfileData() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final credit = context.read<CreditProvider>();
    final insights = context.read<EqubInsightsProvider>();
    final wallet = context.read<WalletProvider>();
    final walletAddress = auth.walletAddress;
    if (walletAddress != null) {
      credit.loadTierEligibility(walletAddress);
      insights.initializeForWallet(walletAddress);
      final network = context.read<NetworkProvider>();
      wallet.loadAll(walletAddress, nativeSymbol: network.nativeSymbol);
    }
  }

  String _shortenAddress(String? address) {
    if (address == null || address.length < 12) return address ?? '—';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _bindWalletAddress(
    BuildContext context,
    AuthProvider auth,
    String walletAddress,
  ) async {
    await auth.bindWallet(walletAddress);
    if (!mounted) return;

    if (auth.errorMessage == null) {
      AppSnackbarService.instance.success(
        message: 'Wallet bound. App session now uses this wallet.',
        dedupeKey: 'profile_wallet_bind_success',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<bool> _connectAndAutoBindWallet(
    BuildContext context,
    AuthProvider auth,
    WalletService walletService,
  ) async {
    final previousBoundAddress = auth.walletAddress;

    await auth.connectWallet();
    if (!mounted) {
      return false;
    }

    final connectedAddress = walletService.walletAddress ?? auth.walletAddress;
    final hasConnectError =
        (walletService.errorMessage ?? auth.errorMessage) != null;
    if (hasConnectError || connectedAddress == null) {
      return false;
    }

    final shouldBind = auth.identityHash != null &&
        (previousBoundAddress == null ||
            previousBoundAddress.toLowerCase() !=
                connectedAddress.toLowerCase());

    if (shouldBind) {
      await _bindWalletAddress(context, auth, connectedAddress);
      if (!mounted || auth.errorMessage != null) {
        return false;
      }
    }

    _loadProfileData();
    return true;
  }

  Future<void> _connectPrivyWallet(
    BuildContext context,
    AuthProvider auth,
    WalletService walletService,
  ) async {
    final connected = await _connectAndAutoBindWallet(
      context,
      auth,
      walletService,
    );
    if (!mounted) {
      return;
    }

    if (!connected) {
      AppSnackbarService.instance.error(
        message: walletService.errorMessage ??
            auth.errorMessage ??
            'Privy wallet connection failed.',
        dedupeKey: 'profile_privy_wallet_connect_failed',
      );
      return;
    }

    AppSnackbarService.instance.success(
      message: 'Privy wallet connected.',
      dedupeKey: 'profile_privy_wallet_connected',
      duration: const Duration(seconds: 2),
    );
  }

  Future<String?> _promptWalletAddress(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? validationMessage;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Bind wallet address'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Wallet address',
                      hintText: '0x...',
                      errorText: validationMessage,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use an EVM address that you control. This does not create a Privy session on web/desktop.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final candidate = controller.text.trim();
                    final isValid =
                        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(candidate);
                    if (!isValid) {
                      setDialogState(() {
                        validationMessage = 'Enter a valid EVM wallet address';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(candidate);
                  },
                  child: const Text('Bind'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _promptAndBindManualWallet(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final walletAddress = await _promptWalletAddress(context);
    if (!mounted || walletAddress == null) {
      return;
    }

    await _bindWalletAddress(context, auth, walletAddress);
    if (!mounted || auth.errorMessage != null) {
      return;
    }

    await auth.saveRememberedWallet(walletAddress);
    _loadProfileData();
  }

  Future<String?> _promptWalletSlotLabel(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Slot name',
              hintText: 'Primary wallet',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim();
  }

  Future<void> _saveWalletSlot(
    BuildContext context,
    AuthProvider auth,
    String walletAddress, {
    String? currentLabel,
  }) async {
    final label = await _promptWalletSlotLabel(
      context,
      title: 'Save wallet slot',
      initialValue: currentLabel,
    );
    if (!mounted || label == null) {
      return;
    }

    await auth.saveRememberedWallet(walletAddress, label: label);
    if (!mounted) {
      return;
    }

    AppSnackbarService.instance.success(
      message: 'Wallet saved to your profile slots.',
      dedupeKey: 'profile_wallet_slot_saved',
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _renameWalletSlot(
    BuildContext context,
    AuthProvider auth,
    StoredWalletSlot slot,
  ) async {
    final label = await _promptWalletSlotLabel(
      context,
      title: 'Rename wallet slot',
      initialValue: slot.label,
    );
    if (!mounted || label == null) {
      return;
    }

    await auth.renameRememberedWallet(slot.address, label);
    if (!mounted) {
      return;
    }

    AppSnackbarService.instance.info(
      message: 'Wallet slot updated.',
      dedupeKey: 'profile_wallet_slot_renamed',
      duration: const Duration(seconds: 2),
    );
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
                onPressed: () => context.push('/profile/edit'),
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
    final auth = context.watch<AuthProvider>();
    final credit = context.watch<CreditProvider>();
    final wallet = context.watch<WalletProvider>();
    final walletService = context.watch<WalletService>();
    final network = context.watch<NetworkProvider>();
    final notifications = context.watch<NotificationProvider>();
    final insights = context.watch<EqubInsightsProvider>();

    final walletAddr = auth.walletAddress;
    final shortAddr = _shortenAddress(walletAddr);
    if (walletAddr != null && walletAddr != _lastLoadedWallet) {
      _lastLoadedWallet = walletAddr;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileData());
    }

    final desktop = AppTheme.isDesktop(context);

    if (desktop) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: DesktopContent(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        DesktopCardSection(
                          child: _buildAvatarSection(
                            context,
                            auth: auth,
                            walletAddr: walletAddr,
                            shortAddr: shortAddr,
                          ),
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildBalanceCard(context, wallet, network),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildCreditCard(context, auth, credit, network),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.desktopPanelGap),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildOperationsSection(
                          context,
                          walletAddress: walletAddr,
                          notifications: notifications,
                          insights: insights,
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildPreferencesSection(
                          context,
                          auth: auth,
                          notifications: notifications,
                          network: network,
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildWalletCard(
                          context,
                          auth,
                          walletService,
                          network,
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildRuntimeStatusCard(
                          context,
                          auth: auth,
                          wallet: wallet,
                          walletService: walletService,
                          network: network,
                          notifications: notifications,
                        ),
                        const SizedBox(height: AppTheme.desktopSectionGap),
                        _buildLogOutButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _buildAvatarSection(
            context,
            auth: auth,
            walletAddr: walletAddr,
            shortAddr: shortAddr,
          ),
          const SizedBox(height: 24),
          _buildBalanceCard(context, wallet, network),
          const SizedBox(height: 28),
          _buildOperationsSection(
            context,
            walletAddress: walletAddr,
            notifications: notifications,
            insights: insights,
          ),
          const SizedBox(height: 24),
          _buildPreferencesSection(
            context,
            auth: auth,
            notifications: notifications,
            network: network,
          ),
          const SizedBox(height: 20),
          _buildWalletCard(context, auth, walletService, network),
          const SizedBox(height: 20),
          _buildCreditCard(context, auth, credit, network),
          const SizedBox(height: 20),
          _buildRuntimeStatusCard(
            context,
            auth: auth,
            wallet: wallet,
            walletService: walletService,
            network: network,
            notifications: notifications,
          ),
          const SizedBox(height: 28),
          _buildLogOutButton(context),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(
    BuildContext context, {
    required AuthProvider auth,
    required String? walletAddr,
    required String shortAddr,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            children: [
              _buildAvatarImage(context, auth.avatarBytes, auth.photoUrl),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/profile/edit'),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor,
                        border: Border.all(
                          color: AppTheme.cardColor(context),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
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
              AppSnackbarService.instance.info(
                  message: 'Wallet address copied',
                  dedupeKey: 'profile_wallet_address_copied',
                  duration: const Duration(seconds: 2));
            }
          },
          child: Text(auth.effectiveDisplayName,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context))),
        ),
        const SizedBox(height: 4),
        Text(
          auth.email ?? '@$shortAddr · Diaspora Member',
          style: TextStyle(
              fontSize: 13, color: AppTheme.textTertiaryColor(context)),
        ),
        if (walletAddr != null) ...[
          const SizedBox(height: 6),
          Text(
            'Wallet: $shortAddr',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarImage(
    BuildContext context,
    Uint8List? avatarBytes,
    String? photoUrl,
  ) {
    ImageProvider<Object>? imageProvider;
    if (avatarBytes != null) {
      imageProvider = MemoryImage(avatarBytes);
    } else if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      imageProvider = NetworkImage(photoUrl);
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.3),
        border: Border.all(color: AppTheme.cardColor(context), width: 3),
        boxShadow: AppTheme.cardShadowFor(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider == null
          ? const Icon(Icons.person, size: 48, color: Colors.white70)
          : Image(
              image: imageProvider,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person, size: 48, color: Colors.white70),
            ),
    );
  }

  Widget _buildWalletCard(
    BuildContext context,
    AuthProvider auth,
    WalletService walletService,
    NetworkProvider network,
  ) {
    final hasPrivyConfig = walletService.hasPrivyConfiguration;
    final isSupportedPlatform = walletService.isSupportedPlatform;
    final connected = walletService.isConnected;
    final wcAddress = walletService.walletAddress;
    final boundAddress = auth.walletAddress;
    final rememberedWallets = auth.rememberedWallets;

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
                color: connected
                    ? AppTheme.positive
                    : AppTheme.textTertiaryColor(context),
              ),
              const SizedBox(width: 10),
              Text(
                'Wallets (${network.shortNetworkName})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              _buildWalletTag(
                context,
                network.shortNetworkName,
                AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your Privy wallet session and the wallet bound to your app identity on ${network.networkName}.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          const SizedBox(height: 14),
          _buildWalletStatusTile(
            context,
            icon: Icons.verified_user_outlined,
            accent: AppTheme.primaryColor,
            label: 'Bound wallet',
            value: boundAddress == null
                ? 'No wallet bound yet'
                : _shortenAddress(boundAddress),
            description: boundAddress == null
                ? 'Security controls stay limited until you bind one wallet to your app identity.'
                : 'This wallet is embedded in your current app session and used by security routes.',
            trailing: boundAddress == null
                ? null
                : TextButton(
                    onPressed: () => context.push('/profile/security'),
                    child: const Text('Security'),
                  ),
          ),
          const SizedBox(height: 12),
          _buildWalletStatusTile(
            context,
            icon: connected
                ? Icons.account_balance_wallet_rounded
                : Icons.link_off_rounded,
            accent:
                connected ? AppTheme.positive : AppTheme.textHintColor(context),
            label: 'Connected session wallet',
            value: connected && wcAddress != null
                ? _shortenAddress(wcAddress)
                : 'No wallet connected',
            description: connected && wcAddress != null
                ? 'This Privy wallet is active for signing on ${network.shortNetworkName}. New connections automatically bind to your profile.'
                : 'Create or restore a Privy wallet for signing on ${network.networkName}.',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: walletService.isConnecting ||
                      !isSupportedPlatform ||
                      !hasPrivyConfig
                  ? null
                  : () => _connectPrivyWallet(
                        context,
                        auth,
                        walletService,
                      ),
              icon: walletService.isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      connected
                          ? Icons.refresh_rounded
                          : Icons.account_balance_wallet_outlined,
                      size: 18,
                    ),
              label: Text(connected
                  ? 'Reconnect Privy Wallet'
                  : 'Connect Privy Wallet'),
            ),
          ),
          if (!isSupportedPlatform || !hasPrivyConfig) ...[
            const SizedBox(height: 10),
            Text(
              !isSupportedPlatform
                  ? 'Privy embedded wallets are only available on Android and iOS. Manual wallet binding remains available on web and desktop.'
                  : 'Add PRIVY_APP_ID and PRIVY_APP_CLIENT_ID to enable embedded wallets in this build.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
          if (hasPrivyConfig && isSupportedPlatform) ...[
            const SizedBox(height: 10),
            Text(
              'Privy uses your signed-in app identity to restore the same embedded wallet session on ${network.shortNetworkName}.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (connected)
                OutlinedButton.icon(
                  onPressed: () async {
                    await walletService.disconnect();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Disconnect'),
                ),
              if (connected && wcAddress != null)
                OutlinedButton.icon(
                  onPressed: () => _saveWalletSlot(context, auth, wcAddress),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save connected wallet'),
                ),
              if (boundAddress != null)
                OutlinedButton.icon(
                  onPressed: () => _saveWalletSlot(context, auth, boundAddress),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Name bound wallet'),
                ),
              if (!isSupportedPlatform || !hasPrivyConfig)
                OutlinedButton.icon(
                  onPressed: () => _promptAndBindManualWallet(context, auth),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Bind address manually'),
                ),
            ],
          ),
          if (connected || boundAddress != null) const SizedBox(height: 14),
          _buildRememberedWalletsSection(
            context,
            auth,
            rememberedWallets,
            boundAddress: boundAddress,
            connectedAddress: wcAddress,
          ),
          if ((walletService.errorMessage ?? auth.errorMessage) != null) ...[
            const SizedBox(height: 12),
            Text(
              walletService.errorMessage ?? auth.errorMessage ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.negative,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletStatusTile(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    required String description,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildRememberedWalletsSection(
    BuildContext context,
    AuthProvider auth,
    List<StoredWalletSlot> rememberedWallets, {
    required String? boundAddress,
    required String? connectedAddress,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remembered wallet slots',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep a short list of recent or named wallets so your profile flow feels like a real wallet manager, not a one-off bind panel.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 12),
          if (rememberedWallets.isEmpty)
            Text(
              'Saved wallets will appear here after you connect or bind one. You can assign names like Primary, Travel, or Treasury.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiaryColor(context),
              ),
            )
          else
            ...rememberedWallets.map(
              (slot) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildRememberedWalletTile(
                  context,
                  auth,
                  slot,
                  boundAddress: boundAddress,
                  connectedAddress: connectedAddress,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRememberedWalletTile(
    BuildContext context,
    AuthProvider auth,
    StoredWalletSlot slot, {
    required String? boundAddress,
    required String? connectedAddress,
  }) {
    final isBound = boundAddress != null &&
        boundAddress.toLowerCase() == slot.address.toLowerCase();
    final isConnected = connectedAddress != null &&
        connectedAddress.toLowerCase() == slot.address.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: AppTheme.borderFor(context, opacity: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (slot.label == null || slot.label!.trim().isEmpty)
                          ? 'Saved wallet'
                          : slot.label!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _shortenAddress(slot.address),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isBound)
                _buildWalletTag(context, 'Bound', AppTheme.primaryColor),
              if (isConnected) ...[
                const SizedBox(width: 6),
                _buildWalletTag(context, 'Connected', AppTheme.positive),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: isBound
                    ? null
                    : () => _bindWalletAddress(context, auth, slot.address),
                child: Text(isBound ? 'Active app wallet' : 'Bind this wallet'),
              ),
              OutlinedButton(
                onPressed: () => _renameWalletSlot(context, auth, slot),
                child: const Text('Rename'),
              ),
              TextButton(
                onPressed: () async {
                  await auth.removeRememberedWallet(slot.address);
                  if (!mounted) {
                    return;
                  }
                  AppSnackbarService.instance.info(
                    message: 'Wallet slot removed.',
                    dedupeKey: 'profile_wallet_slot_removed',
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTag(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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

  Widget _buildBalanceCard(
    BuildContext context,
    WalletProvider wallet,
    NetworkProvider network,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txCount = wallet.transactions.length;
    final lastTx = txCount > 0 ? wallet.transactions.first : null;
    final lastToken = lastTx?['token']?.toString() ?? wallet.token;
    final lastType = lastTx?['type']?.toString();
    final activitySummary = wallet.isLoading
        ? 'Refreshing balances and wallet activity on ${network.shortNetworkName}.'
        : txCount == 0
            ? 'No recent wallet movements have been loaded yet.'
            : '$txCount recent wallet movements loaded. Latest ${lastType ?? 'activity'} uses $lastToken.';

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
              Text('Total Balance',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.currency_exchange_rounded,
                    size: 18, color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$${wallet.balance}',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                txCount > 0 ? Icons.sync_rounded : Icons.info_outline_rounded,
                size: 16,
                color: txCount > 0
                    ? AppTheme.positive
                    : AppTheme.textTertiaryColor(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activitySummary,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: txCount > 0
                        ? AppTheme.positive
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildWalletTag(context, wallet.token, AppTheme.primaryColor),
              _buildWalletTag(
                context,
                network.shortNetworkName,
                AppTheme.secondaryColor,
              ),
              _buildWalletTag(
                context,
                txCount == 0 ? 'No recent tx' : '$txCount tx loaded',
                txCount == 0
                    ? AppTheme.textTertiaryColor(context)
                    : AppTheme.positive,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => context.push('/fund-wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor(context),
                      foregroundColor: AppTheme.buttonTextColor(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Top Up',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Withdraw',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsSection(
    BuildContext context, {
    required String? walletAddress,
    required NotificationProvider notifications,
    required EqubInsightsProvider insights,
  }) {
    final joinedPools = insights.joinedPools;
    final summary = insights.summary;
    final activePools = (summary['activePools'] as num?)?.toInt() ?? 0;
    final endingSoon = (summary['endingSoon'] as num?)?.toInt() ?? 0;
    final winnerPending = (summary['winnerPending'] as num?)?.toInt() ?? 0;
    final waitingOnUser = joinedPools.where((pool) {
      final completion = (pool['completionPct'] as num?)?.toDouble() ?? 0.0;
      final status = pool['status']?.toString().toLowerCase() ?? '';
      return status == 'active' && completion < 100;
    }).length;
    final desktop = AppTheme.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('OPERATIONS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textTertiaryColor(context))),
        ),
        Container(
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
              Text(
                'Your live Equb workload',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                walletAddress == null
                    ? 'Bind a wallet to load joined pool progress, payout pressure, and action queues.'
                    : 'Track joined pools, payout pressure, and action queues from your current app wallet.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 16),
              if (walletAddress == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                    border: AppTheme.borderFor(context, opacity: 0.05),
                  ),
                  child: Text(
                    'No wallet bound yet. The operations panel will fill with joined pools and payout metrics after wallet binding.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackSummary = constraints.maxWidth < 520;
                    final summaryCards = [
                      _buildOpsSummaryBox(
                        context,
                        title: 'Active Pools',
                        value: '$activePools',
                        accent: AppTheme.primaryColor,
                        icon: Icons.groups_rounded,
                      ),
                      _buildOpsSummaryBox(
                        context,
                        title: 'Ending Soon',
                        value: '$endingSoon',
                        accent: AppTheme.warningColor,
                        icon: Icons.schedule_rounded,
                      ),
                      _buildOpsSummaryBox(
                        context,
                        title: 'Winner Pending',
                        value: '$winnerPending',
                        accent: AppTheme.secondaryColor,
                        icon: Icons.emoji_events_outlined,
                      ),
                      _buildOpsSummaryBox(
                        context,
                        title: 'Unread Alerts',
                        value: '${notifications.unreadCount}',
                        accent: AppTheme.accentYellow,
                        icon: Icons.notifications_active_outlined,
                      ),
                    ];

                    if (stackSummary) {
                      return Column(
                        children: [
                          for (int i = 0; i < summaryCards.length; i++) ...[
                            summaryCards[i],
                            if (i != summaryCards.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    return GridView.count(
                      crossAxisCount: desktop ? 2 : 2,
                      childAspectRatio: desktop ? 1.7 : 1.5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: summaryCards,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildOpsActionStrip(
                  context,
                  waitingOnUser: waitingOnUser,
                  notifications: notifications.unreadCount,
                  winnerPending: winnerPending,
                ),
                const SizedBox(height: 16),
                if (insights.summaryLoading || insights.joinedLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (insights.summaryError != null ||
                    insights.joinedError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.cardColor(context).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: AppTheme.borderFor(context, opacity: 0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insights.summaryError ??
                              insights.joinedError ??
                              'Failed to load operations data.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.negative,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => insights.refresh(walletAddress),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry operations data'),
                        ),
                      ],
                    ),
                  )
                else
                  _buildJoinedPoolsOperationsList(
                    context,
                    pools: joinedPools,
                    notifications: notifications.unreadCount,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpsSummaryBox(
    BuildContext context, {
    required String title,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpsActionStrip(
    BuildContext context, {
    required int waitingOnUser,
    required int notifications,
    required int winnerPending,
  }) {
    final headline = winnerPending > 0
        ? '$winnerPending payout decisions are waiting.'
        : waitingOnUser > 0
            ? '$waitingOnUser active pools still need contributions or review.'
            : notifications > 0
                ? '$notifications unread notifications need review.'
                : 'Your pool operations are currently clear.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.96),
            AppTheme.secondaryColor.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations focus',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push('/equb-insights'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                ),
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: const Text('Open Insights'),
              ),
              OutlinedButton.icon(
                onPressed: () => context
                    .push(winnerPending > 0 ? '/notifications' : '/pools'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
                icon: Icon(
                  winnerPending > 0
                      ? Icons.notifications_active_outlined
                      : Icons.groups_rounded,
                  size: 18,
                ),
                label: Text(
                  winnerPending > 0 ? 'Review Alerts' : 'Open Equbs',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedPoolsOperationsList(
    BuildContext context, {
    required List<Map<String, dynamic>> pools,
    required int notifications,
  }) {
    if (pools.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: AppTheme.borderFor(context, opacity: 0.05),
        ),
        child: Text(
          notifications > 0
              ? 'No joined pool progress is available for the active filters yet, but you still have unread notifications to review.'
              : 'No joined pool progress is available for the active filters yet.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Joined pool queue',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...List.generate(math.min(pools.length, 3), (index) {
          final pool = pools[index];
          final poolId = pool['poolId']?.toString() ?? '';
          final poolName = pool['poolName']?.toString() ??
              (pool['onChainPoolId'] != null
                  ? 'Pool #${pool['onChainPoolId']}'
                  : 'Equb Pool');
          final completion = (pool['completionPct'] as num?)?.toDouble() ?? 0.0;
          final roundsDone = (pool['roundsDone'] as num?)?.toInt() ?? 0;
          final roundsTotal = (pool['roundsTotal'] as num?)?.toInt() ?? 0;
          final status = pool['status']?.toString().toLowerCase() ?? 'active';
          final needsAttention = status == 'active' && completion < 100;

          return Padding(
            padding: EdgeInsets.only(
                bottom: index == math.min(pools.length, 3) - 1 ? 0 : 10),
            child: InkWell(
              onTap:
                  poolId.isEmpty ? null : () => context.push('/pools/$poolId'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: AppTheme.borderFor(context, opacity: 0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            poolName,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _buildWalletTag(
                          context,
                          needsAttention ? 'Needs action' : status,
                          needsAttention
                              ? AppTheme.warningColor
                              : AppTheme.secondaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completion ${completion.toStringAsFixed(0)}% • Rounds $roundsDone/${roundsTotal == 0 ? '-' : roundsTotal}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (completion / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppTheme.textHintColor(context)
                            .withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          needsAttention
                              ? AppTheme.warningColor
                              : AppTheme.positive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context, {
    required AuthProvider auth,
    required NotificationProvider notifications,
    required NetworkProvider network,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('PREFERENCES',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textTertiaryColor(context))),
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
                notifications.unreadCount == 0
                    ? 'Notifications are clear'
                    : '${notifications.unreadCount} unread notifications',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notifications.unreadCount > 0)
                      _buildWalletTag(
                        context,
                        '${notifications.unreadCount} unread',
                        AppTheme.accentYellow,
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        size: 22, color: AppTheme.textTertiaryColor(context)),
                  ],
                ),
                onTap: () => context.push('/notifications'),
              ),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(context, Icons.dark_mode_outlined,
                  AppTheme.primaryColor, 'Dark Mode',
                  trailing: Switch.adaptive(
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleDarkMode(),
                      activeThumbColor: AppTheme.accentYellow,
                      activeTrackColor: AppTheme.secondaryColor)),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(
                context,
                Icons.hub_outlined,
                AppTheme.primaryColor,
                'Creditcoin ${network.shortNetworkName}',
                trailing: Switch.adaptive(
                  value: network.isMainnet,
                  onChanged: (value) => network.setTestnet(!value),
                  activeThumbColor: AppTheme.primaryColor,
                  activeTrackColor: AppTheme.secondaryColor,
                ),
              ),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(
                context,
                Icons.verified_user_outlined,
                AppTheme.positive,
                'Transaction confirmation',
                trailing: Switch.adaptive(
                  value: auth.requireTransactionConfirmation,
                  onChanged: auth.updateTransactionConfirmationPreference,
                  activeThumbColor: AppTheme.positive,
                  activeTrackColor: AppTheme.positive.withValues(alpha: 0.45),
                ),
              ),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildPreferenceRow(context, Icons.help_outline_rounded,
                  AppTheme.secondaryColor, 'Help & Support',
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 22, color: AppTheme.textTertiaryColor(context)),
                  onTap: () => context.push('/profile/help')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuntimeStatusCard(
    BuildContext context, {
    required AuthProvider auth,
    required WalletProvider wallet,
    required WalletService walletService,
    required NetworkProvider network,
    required NotificationProvider notifications,
  }) {
    final apiBase = Uri.tryParse(AppConfig.apiBaseUrl);
    final apiHost =
        apiBase?.host.isNotEmpty == true ? apiBase!.host : AppConfig.apiBaseUrl;

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
          Text(
            'Live App Status',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Real session and runtime state for this device. No placeholder metrics.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(context, 'App auth state',
              auth.isAuthenticated ? 'Authenticated' : 'Guest'),
          const Divider(height: 20),
          _buildInfoRow(
              context,
              'Connected wallet',
              walletService.walletAddress == null
                  ? 'Not connected'
                  : _shortenAddress(walletService.walletAddress)),
          const Divider(height: 20),
          _buildInfoRow(
              context,
              'Bound wallet',
              auth.walletAddress == null
                  ? 'Not bound'
                  : _shortenAddress(auth.walletAddress)),
          const Divider(height: 20),
          _buildInfoRow(context, 'Network',
              '${network.networkName} (${network.chainId})'),
          const Divider(height: 20),
          _buildInfoRow(context, 'API', apiHost),
          const Divider(height: 20),
          _buildInfoRow(context, 'Privy config',
              walletService.hasPrivyConfiguration ? 'Configured' : 'Missing'),
          const Divider(height: 20),
          _buildInfoRow(
              context, 'Unread notifications', '${notifications.unreadCount}'),
          const Divider(height: 20),
          _buildInfoRow(
              context, 'Loaded transactions', '${wallet.transactions.length}'),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(
      BuildContext context, IconData icon, Color iconColor, String title,
      {Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context)))),
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
        icon: const Icon(Icons.logout_rounded,
            size: 20, color: AppTheme.negative),
        label: const Text('Log Out',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.negative)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.negative.withValues(alpha: 0.3)),
          backgroundColor: AppTheme.negative.withValues(alpha: 0.06),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCreditCard(
    BuildContext context,
    AuthProvider auth,
    CreditProvider credit,
    NetworkProvider network,
  ) {
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.videogame_asset_rounded,
                  color: AppTheme.accentYellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credit Arena',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Level up your trust score by contributing on time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/credit'),
                child: const Text('View details'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (credit.isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            LinearProgressIndicator(
              value: _creditProgressValue(
                credit.score,
                credit.nextTier,
                credit.scoreForNextTier,
              ),
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor:
                  AppTheme.textHintColor(context).withValues(alpha: 0.22),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.positive),
            ),
          const SizedBox(height: 18),
          _buildInfoRow(
              context, 'Identity', _shortenAddress(auth.identityHash)),
          const Divider(height: 20),
          _buildInfoRow(context, 'Credit Score', '${credit.score}'),
          const Divider(height: 20),
          _buildInfoRow(
              context, 'Eligible Tier', 'Tier ${credit.eligibleTier}'),
          const Divider(height: 20),
          _buildInfoRow(
              context, 'Collateral Rate', '${credit.collateralRate / 100}%'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Max Equb Size', '\$${credit.maxPoolSize}'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Network', network.shortNetworkName),
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

  double _creditProgressValue(
    int score,
    int? nextTier,
    int? scoreForNextTier,
  ) {
    if (nextTier == null) {
      return 1;
    }
    if (scoreForNextTier == null || scoreForNextTier == 0) {
      return 0;
    }

    return (score / scoreForNextTier).clamp(0.0, 1.0);
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
