import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/wallet_provider.dart';
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
      wallet.loadAll(auth.walletAddress!);
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
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
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

        // Show WalletConnect pairing dialog when connecting
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
              // Avatar
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.textTertiary.withValues(alpha: 0.3),
                  border: Border.all(color: AppTheme.cardWhite, width: 3),
                  boxShadow: AppTheme.cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://i.pravatar.cc/150?img=12',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    size: 44,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Wallet address (tappable to copy)
              GestureDetector(
                onTap: () {
                  if (walletAddr != null) {
                    Clipboard.setData(ClipboardData(text: walletAddr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wallet address copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortAddr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.content_copy_rounded,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Credit tier badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tier ${credit.eligibleTier} • Score ${credit.score}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Balance card
              _buildBalanceCard(context, balance, wallet.token),
              const SizedBox(height: 20),
              // WalletConnect (testnet) card
              _buildWalletConnectCard(context, auth, walletService),
              const SizedBox(height: 28),
              // Info rows
              _buildInfoCard(context, auth, credit),
              const SizedBox(height: 28),
              // Action buttons
              _buildBottomActions(context),
            ],
          ),
        );
      },
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
                  const Text(
                    'Scan with MetaMask or any WalletConnect-compatible wallet (Creditcoin Testnet)',
                    style: TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (uri.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: uri,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for approval...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
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
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_off_rounded,
                    size: 22, color: AppTheme.textTertiary),
                SizedBox(width: 10),
                Text(
                  'WalletConnect',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Set WALLETCONNECT_PROJECT_ID (from cloud.walletconnect.com) via --dart-define to enable testnet wallet signing.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
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
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadow,
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
                color: connected ? AppTheme.positive : AppTheme.textTertiary,
              ),
              const SizedBox(width: 10),
              const Text(
                'WalletConnect (Testnet)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            connected
                ? 'Connected: ${_shortenAddress(wcAddress)}'
                : 'Connect your wallet to sign pool, collateral and transfer transactions on Creditcoin Testnet.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          if (walletService.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              walletService.errorMessage!,
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
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isBindingWallet = true);
                          await auth.bindWallet(wcAddress);
                          setState(() => _isBindingWallet = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Wallet bound. App will use this address.'),
                                duration: Duration(seconds: 2),
                              ),
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
                  onPressed: walletService.isConnecting
                      ? null
                      : () {
                          walletService.connect();
                          setState(() {});
                        },
                  icon: walletService.isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(walletService.isConnecting
                      ? 'Connecting...'
                      : 'Connect wallet'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wallet Balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      token,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Amount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentYellow.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$$balance',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Dot chart
          const SizedBox(
            height: 140,
            child: _DotChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, AuthProvider auth, CreditProvider credit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          _buildInfoRow('Identity', _shortenAddress(auth.identityHash)),
          const Divider(height: 20),
          _buildInfoRow('Eligible Tier', 'Tier ${credit.eligibleTier}'),
          const Divider(height: 20),
          _buildInfoRow('Collateral Rate', '${credit.collateralRate / 100}%'),
          const Divider(height: 20),
          _buildInfoRow('Max Pool Size', '\$${credit.maxPoolSize}'),
          if (credit.nextTier != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              'Next Tier',
              'Tier ${credit.nextTier} (need ${credit.scoreForNextTier} pts)',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final actions = [
      {
        'icon': Icons.shield_outlined,
        'label': 'Collateral',
        'color': const Color(0xFF14B8A6),
        'route': '/collateral',
      },
      {
        'icon': Icons.trending_up_rounded,
        'label': 'Credit Score',
        'color': const Color(0xFF6366F1),
        'route': '/credit',
      },
      {
        'icon': Icons.groups_rounded,
        'label': 'Pools',
        'color': const Color(0xFF3B82F6),
        'route': '/pools',
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.push(a['route'] as String),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (a['color'] as Color).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  a['icon'] as IconData,
                  size: 24,
                  color: a['color'] as Color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                a['label'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Custom dot-pattern chart widget matching the reference design.
class _DotChart extends StatelessWidget {
  const _DotChart();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const cols = 30;
        const rows = 10;
        final dotSpacingX = width / cols;
        final dotSpacingY = height / rows;
        final dotRadius = (dotSpacingX * 0.28).clamp(1.5, 3.0);

        // Generate pseudo-random "spend" data per column
        final rng = Random(42);
        final data = List.generate(cols, (i) {
          final base = sin(i / cols * pi * 2 - 0.5) * 0.4 + 0.3;
          final peak =
              i >= 18 && i <= 23 ? 0.4 * (1 - ((i - 20.5).abs() / 3)) : 0.0;
          return (base + peak + rng.nextDouble() * 0.15).clamp(0.0, 1.0);
        });

        return CustomPaint(
          size: Size(width, height),
          painter: _DotChartPainter(
            data: data,
            cols: cols,
            rows: rows,
            dotSpacingX: dotSpacingX,
            dotSpacingY: dotSpacingY,
            dotRadius: dotRadius,
          ),
        );
      },
    );
  }
}

class _DotChartPainter extends CustomPainter {
  final List<double> data;
  final int cols;
  final int rows;
  final double dotSpacingX;
  final double dotSpacingY;
  final double dotRadius;

  _DotChartPainter({
    required this.data,
    required this.cols,
    required this.rows,
    required this.dotSpacingX,
    required this.dotSpacingY,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final greyPaint = Paint()..color = const Color(0xFFD1D5DB);
    final yellowPaint = Paint()..color = AppTheme.accentYellow;
    final peakPaint = Paint()
      ..color = AppTheme.accentYellow
      ..style = PaintingStyle.fill;

    int peakCol = 0;
    double peakVal = 0;
    for (int c = 0; c < cols; c++) {
      if (data[c] > peakVal) {
        peakVal = data[c];
        peakCol = c;
      }
    }

    for (int c = 0; c < cols; c++) {
      final filledRows = (data[c] * rows).round();
      for (int r = 0; r < rows; r++) {
        final x = c * dotSpacingX + dotSpacingX / 2;
        final y = size.height - (r * dotSpacingY + dotSpacingY / 2);
        final isFilled = r < filledRows;

        canvas.drawCircle(
          Offset(x, y),
          dotRadius,
          isFilled ? yellowPaint : greyPaint,
        );
      }
    }

    // Draw peak indicator
    final peakX = peakCol * dotSpacingX + dotSpacingX / 2;
    final peakFilledRows = (data[peakCol] * rows).round();
    final peakY =
        size.height - (peakFilledRows * dotSpacingY + dotSpacingY / 2);

    canvas.drawCircle(
      Offset(peakX, peakY - 4),
      dotRadius * 4,
      Paint()
        ..color = AppTheme.accentYellow.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(Offset(peakX, peakY - 4), dotRadius * 2, peakPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
