import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/network_provider.dart';
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
  bool _isBindingWallet = false;
  final _manualWalletController = TextEditingController();

  @override
  void dispose() {
    _manualWalletController.dispose();
    super.dispose();
  }

  void _loadProfileData() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final credit = context.read<CreditProvider>();
    final wallet = context.read<WalletProvider>();
    final walletAddress = auth.walletAddress;
    if (walletAddress != null) {
      credit.loadTierEligibility(walletAddress);
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
    setState(() => _isBindingWallet = true);
    await auth.bindWallet(walletAddress);
    if (!mounted) return;
    setState(() => _isBindingWallet = false);

    if (auth.errorMessage == null) {
      AppSnackbarService.instance.success(
        message: 'Wallet bound. App session now uses this wallet.',
        dedupeKey: 'profile_wallet_bind_success',
        duration: const Duration(seconds: 2),
      );
    }
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
    return Consumer5<AuthProvider, CreditProvider, WalletProvider,
        WalletService, NetworkProvider>(
      builder: (context, auth, credit, wallet, walletService, network, _) {
        final walletAddr = auth.walletAddress;
        final shortAddr = _shortenAddress(walletAddr);
        final balance = wallet.balance;
        if (walletAddr != null && walletAddr != _lastLoadedWallet) {
          _lastLoadedWallet = walletAddr;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _loadProfileData());
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
                            _buildBalanceCard(context, balance, wallet.token),
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
                            _buildAccountSection(context),
                            const SizedBox(height: AppTheme.desktopSectionGap),
                            _buildPreferencesSection(context),
                            const SizedBox(height: AppTheme.desktopSectionGap),
                            _buildWalletConnectCard(
                              context,
                              auth,
                              walletService,
                              network,
                            ),
                            const SizedBox(height: AppTheme.desktopSectionGap),
                            _buildLogOutButton(context),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Version 1.0.0 (Build 1)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiaryColor(context),
                                ),
                              ),
                            ),
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
              _buildBalanceCard(context, balance, wallet.token),
              const SizedBox(height: 28),
              _buildAccountSection(context),
              const SizedBox(height: 24),
              _buildPreferencesSection(context),
              const SizedBox(height: 20),
              _buildWalletConnectCard(context, auth, walletService, network),
              const SizedBox(height: 20),
              _buildCreditCard(context, auth, credit, network),
              const SizedBox(height: 28),
              _buildLogOutButton(context),
              const SizedBox(height: 16),
              Text('Version 1.0.0 (Build 1)',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiaryColor(context))),
            ],
          ),
        );
      },
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

  Widget _buildWalletConnectCard(
    BuildContext context,
    AuthProvider auth,
    WalletService walletService,
    NetworkProvider network,
  ) {
    final hasProjectId = AppConfig.walletConnectProjectId.isNotEmpty;
    final connected = walletService.isConnected;
    final wcAddress = walletService.walletAddress;
    final boundAddress = auth.walletAddress;
    final canBind = connected && wcAddress != null && wcAddress != boundAddress;
    final sameWallet =
        connected && wcAddress != null && wcAddress == boundAddress;
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manage which wallet is connected right now and which one is bound to your app identity on ${network.networkName}.',
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
                ? (sameWallet
                    ? 'The connected wallet already matches the wallet bound to your account.'
                    : 'You can bind this connected wallet to replace the current app wallet.')
                : 'Connect a browser wallet or WalletConnect-compatible wallet for signing.',
            trailing: connected
                ? TextButton(
                    onPressed: () async {
                      await walletService.disconnect();
                      if (mounted) setState(() {});
                    },
                    child: const Text('Disconnect'),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: walletService.isConnecting
                    ? null
                    : () async {
                        await auth.connectWallet();
                      },
                icon:
                    const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text('MetaMask / Browser Wallet'),
              ),
              FilledButton.tonalIcon(
                onPressed: (!hasProjectId || walletService.isConnecting)
                    ? null
                    : () async {
                        await auth.connectWallet();
                      },
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('WalletConnect / Trust Wallet'),
              ),
              FilledButton.tonalIcon(
                onPressed: (!hasProjectId || walletService.isConnecting)
                    ? null
                    : () async {
                        await auth.connectWallet();
                      },
                icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                label: const Text('Creditcoin-Compatible Wallet'),
              ),
            ],
          ),
          if (!hasProjectId) ...[
            const SizedBox(height: 10),
            Text(
              'Add WALLETCONNECT_PROJECT_ID to enable WalletConnect-hosted wallets during development.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isBindingWallet || !canBind)
                      ? null
                      : () => _bindWalletAddress(context, auth, wcAddress),
                  icon: _isBindingWallet
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(canBind
                      ? 'Bind connected wallet'
                      : sameWallet
                          ? 'Connected wallet active'
                          : 'Connect first to bind'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.push('/wallet-binding'),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Advanced setup'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (connected && wcAddress != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _saveWalletSlot(context, auth, wcAddress),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Save connected wallet as slot'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (boundAddress != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _saveWalletSlot(context, auth, boundAddress),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Name current bound wallet'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _buildRememberedWalletsSection(
            context,
            auth,
            rememberedWallets,
            boundAddress: boundAddress,
            connectedAddress: wcAddress,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: AppTheme.borderFor(context, opacity: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manual bind',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (boundAddress != null)
                      Text(
                        'Current: ${_shortenAddress(boundAddress)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste an EVM wallet address for dev/test flows or when you want to bind a wallet that is not currently connected in this session.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualWalletController,
                  decoration: const InputDecoration(
                    labelText: 'Wallet address',
                    hintText: '0x...',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _isBindingWallet
                        ? null
                        : () {
                            final walletAddress =
                                _manualWalletController.text.trim();
                            final isValid = RegExp(r'^0x[a-fA-F0-9]{40}$')
                                .hasMatch(walletAddress);
                            if (!isValid) {
                              AppSnackbarService.instance.error(
                                message: 'Enter a valid EVM wallet address',
                                dedupeKey: 'profile_invalid_wallet_bind',
                              );
                              return;
                            }

                            _bindWalletAddress(context, auth, walletAddress);
                          },
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Bind pasted wallet'),
                  ),
                ),
              ],
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
          if (walletService.pairingUri != null &&
              walletService.pairingUri!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: AppTheme.borderFor(context, opacity: 0.06),
                ),
                child: QrImageView(
                  data: walletService.pairingUri!,
                  version: QrVersions.auto,
                  size: 160,
                ),
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
          Text('\$$balance',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -1)),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 16, color: AppTheme.positive),
              SizedBox(width: 4),
              Text('+\$0.00 (0%)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.positive)),
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

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('ACCOUNT',
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
              _buildAccountRow(
                  context,
                  Icons.person_outline_rounded,
                  AppTheme.secondaryColor,
                  'Personal Info',
                  'Name, email, phone',
                  onTap: () => context.push('/profile/edit')),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildAccountRow(context, Icons.groups_outlined,
                  AppTheme.primaryColor, 'Equb Groups', 'Manage your circles',
                  onTap: () => context.push('/pools')),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildAccountRow(context, Icons.shield_outlined,
                  AppTheme.positive, 'Security', 'Password, 2FA, FaceID',
                  onTap: () => context.push('/profile/security')),
              Divider(
                  height: 1,
                  indent: 60,
                  color:
                      AppTheme.textHintColor(context).withValues(alpha: 0.3)),
              _buildAccountRow(
                  context,
                  Icons.videogame_asset_outlined,
                  AppTheme.accentYellow,
                  'Credit Score',
                  'Tier progress and perks',
                  onTap: () => context.push('/credit')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRow(BuildContext context, IconData icon, Color iconColor,
      String title, String subtitle,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiaryColor(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 22, color: AppTheme.textTertiaryColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final networkProvider = context.watch<NetworkProvider>();
    final auth = context.watch<AuthProvider>();
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
                'Notifications',
                trailing: Switch.adaptive(
                  value: false,
                  onChanged: (_) {},
                  activeThumbColor: AppTheme.positive,
                  activeTrackColor: AppTheme.positive.withValues(alpha: 0.45),
                ),
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
                'Creditcoin ${networkProvider.shortNetworkName}',
                trailing: Switch.adaptive(
                  value: networkProvider.isMainnet,
                  onChanged: (value) => networkProvider.setTestnet(!value),
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
          LinearProgressIndicator(
            value: _creditProgressValue(
              credit.maxPoolSize,
              credit.nextTier,
              credit.scoreForNextTier,
            ),
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor:
                AppTheme.textHintColor(context).withValues(alpha: 0.22),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.positive),
          ),
          const SizedBox(height: 18),
          _buildInfoRow(
              context, 'Identity', _shortenAddress(auth.identityHash)),
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
    String maxPoolSize,
    int? nextTier,
    int? scoreForNextTier,
  ) {
    if (nextTier == null) {
      return 1;
    }
    if (scoreForNextTier == null || scoreForNextTier == 0) {
      return 0.35;
    }

    final numericPoolSize = int.tryParse(maxPoolSize) ?? 0;
    return ((numericPoolSize % 100) / 100).clamp(0.15, 0.95);
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
