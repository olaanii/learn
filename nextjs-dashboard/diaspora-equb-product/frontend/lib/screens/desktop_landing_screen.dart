import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

class DesktopLandingScreen extends StatefulWidget {
  const DesktopLandingScreen({super.key});

  @override
  State<DesktopLandingScreen> createState() => _DesktopLandingScreenState();
}

class _DesktopLandingScreenState extends State<DesktopLandingScreen> {
  static const String _heroPreviewAsset = 'assets/landing-mobile-preview.png';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _insightsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final sectionContext = key.currentContext;
    if (sectionContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 1180;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LandingTopBar(
                                  onFeaturesTap: () => _scrollTo(_featuresKey),
                                  onHowItWorksTap: () =>
                                      _scrollTo(_insightsKey),
                                  onCompanyTap: () => _scrollTo(_heroKey),
                                ),
                                const SizedBox(height: 18),
                                if (stacked)
                                  Column(
                                    children: [
                                      _HeroCopyPanel(key: _heroKey),
                                      const SizedBox(height: 14),
                                      _HeroVisualPanel(
                                        heroPreviewAsset: _heroPreviewAsset,
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    height: 560,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 10,
                                          child: _HeroCopyPanel(key: _heroKey),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 11,
                                          child: _HeroVisualPanel(
                                            heroPreviewAsset: _heroPreviewAsset,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                if (stacked)
                                  Column(
                                    children: [
                                      _SecurityPanel(key: _featuresKey),
                                      const SizedBox(height: 14),
                                      _InsightsPanel(key: _insightsKey),
                                    ],
                                  )
                                else
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child:
                                              _SecurityPanel(key: _featuresKey),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 4,
                                          child:
                                              _InsightsPanel(key: _insightsKey),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                _ValueStrip(textTheme: textTheme),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LandingTopBar extends StatelessWidget {
  final VoidCallback onFeaturesTap;
  final VoidCallback onHowItWorksTap;
  final VoidCallback onCompanyTap;

  const _LandingTopBar({
    required this.onFeaturesTap,
    required this.onHowItWorksTap,
    required this.onCompanyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 138,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentYellowDark.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.accentYellow.withValues(alpha: 0.72),
            ),
          ),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const Spacer(),
        _TopBarButton(label: 'Features', onTap: onFeaturesTap),
        const SizedBox(width: 8),
        _TopBarButton(label: 'How It Works', onTap: onHowItWorksTap),
        const SizedBox(width: 8),
        _TopBarButton(label: 'Company', onTap: onCompanyTap),
        const SizedBox(width: 18),
        ElevatedButton.icon(
          onPressed: () => context.go('/auth'),
          icon: const Icon(Icons.south_west_rounded, size: 18),
          label: const Text('Open App'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkAccent,
            foregroundColor: AppTheme.darkBackground,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopBarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.darkTextPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

class _HeroCopyPanel extends StatelessWidget {
  const _HeroCopyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 520),
      child: _LandingPanel(
        padding: const EdgeInsets.fromLTRB(36, 40, 36, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.darkBorder.withValues(alpha: 0.85),
                ),
              ),
              child: Text(
                'Desktop-first savings workspace',
                style: textTheme.labelLarge?.copyWith(
                  color: AppTheme.darkAccent,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Your Equb,\nSimplified.',
              style: textTheme.displayLarge?.copyWith(
                color: AppTheme.darkTextPrimary,
                height: 0.94,
                fontWeight: FontWeight.w800,
                fontSize: 64,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                'Control payouts, pool activity, governance, and wallet actions from one desktop command center built around larger screens and calmer decision making.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppTheme.darkTextSecondary,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkAccent,
                    foregroundColor: AppTheme.darkBackground,
                  ),
                  child: const Text('Get Started'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/pools'),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text('Explore Pools'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkTextPrimary,
                    side: BorderSide(
                      color: AppTheme.darkBorder.withValues(alpha: 0.95),
                    ),
                    backgroundColor:
                        AppTheme.darkSurface.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: const [
                _MutedBrandLabel(label: 'Wallet-ready'),
                _MutedBrandLabel(label: 'Round insights'),
                _MutedBrandLabel(label: 'Payout control'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedBrandLabel extends StatelessWidget {
  final String label;

  const _MutedBrandLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.darkTextTertiary.withValues(alpha: 0.86),
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _HeroVisualPanel extends StatelessWidget {
  final String heroPreviewAsset;

  const _HeroVisualPanel({required this.heroPreviewAsset});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 520),
      child: _LandingPanel(
        padding: const EdgeInsets.all(0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = math.min(constraints.maxWidth * 1.06, 760.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 34,
                  left: 36,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  right: 42,
                  top: 26,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentYellow.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.darkSurface.withValues(alpha: 0.92),
                          AppTheme.darkBackground,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: const Offset(0, 18),
                      child: SizedBox(
                        width: imageWidth,
                        child: Image.asset(
                          heroPreviewAsset,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return const _HeroDeviceFallback();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.darkBackground.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroDeviceFallback extends StatelessWidget {
  const _HeroDeviceFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: const [
        Positioned(
          left: 92,
          top: 36,
          bottom: 22,
          child: _PhoneMockup(
            rotationDegrees: -10,
            accentMode: _PhoneAccentMode.chart,
          ),
        ),
        Positioned(
          right: 74,
          top: 58,
          bottom: 10,
          child: _PhoneMockup(
            rotationDegrees: 8,
            accentMode: _PhoneAccentMode.balance,
          ),
        ),
      ],
    );
  }
}

enum _PhoneAccentMode { chart, balance }

class _PhoneMockup extends StatelessWidget {
  final double rotationDegrees;
  final _PhoneAccentMode accentMode;

  const _PhoneMockup({
    required this.rotationDegrees,
    required this.accentMode,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: Container(
        width: 212,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: AppTheme.cardWhite.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkBackground.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '9:41',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.cardWhite,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Container(
                      width: 52,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 82,
                          decoration: BoxDecoration(
                            color: AppTheme.darkAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: accentMode == _PhoneAccentMode.chart
                              ? const _PhoneChartCard()
                              : const _PhoneBalanceCard(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(
                            3,
                            (index) => Expanded(
                              child: Container(
                                height: 54,
                                margin: EdgeInsets.only(
                                  right: index == 2 ? 0 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? AppTheme.darkBackground
                                      : AppTheme.cardWhite,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.textHint
                                        .withValues(alpha: 0.34),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Column(
                            children: List.generate(
                              4,
                              (index) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                      bottom: index == 3 ? 0 : 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardWhite,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.textHint
                                          .withValues(alpha: 0.34),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index.isEven
                                              ? AppTheme.accentYellow
                                                  .withValues(alpha: 0.2)
                                              : AppTheme.secondaryColor
                                                  .withValues(alpha: 0.18),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: AppTheme.textHint
                                                    .withValues(alpha: 0.4),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: 72,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: AppTheme.textHint
                                                    .withValues(alpha: 0.24),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 38,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: AppTheme.darkBackground
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneChartCard extends StatelessWidget {
  const _PhoneChartCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ANALYTICS',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.darkBackground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _MiniBar(height: 28),
              SizedBox(width: 8),
              _MiniBar(height: 44),
              SizedBox(width: 8),
              _MiniBar(height: 58),
              SizedBox(width: 8),
              _MiniBar(height: 36),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double height;

  const _MiniBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.darkBackground.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _PhoneBalanceCard extends StatelessWidget {
  const _PhoneBalanceCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.darkBackground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Available now',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkBackground,
                ),
          ),
          Text(
            'ETB 24,320',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.darkBackground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _LandingPanel(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your finances, safe haven.',
            style: textTheme.headlineMedium?.copyWith(
              color: AppTheme.darkTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: const [
              Expanded(
                child: _FeatureTile(
                  icon: Icons.lock_rounded,
                  title: 'Protected pool actions',
                  body:
                      'Member approvals, payouts, and wallet checks run inside a safer, more deliberate desktop workflow.',
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _FeatureTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Wallet-linked verification',
                  body:
                      'Identity, confirmations, and transaction review stay close to each critical action before anything moves on-chain.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.darkBorder.withValues(alpha: 0.92),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.cardWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.darkTextPrimary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.darkTextSecondary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _LandingPanel(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Track every round easily.',
            style: textTheme.headlineMedium?.copyWith(
              color: AppTheme.darkTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SegmentPill(label: 'Categorization', active: true),
              _SegmentPill(label: 'Expenses'),
              _SegmentPill(label: 'Planning'),
              _SegmentPill(label: 'Insights'),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(
            height: 180,
            child: _InsightsChart(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _LegendStat(label: 'Collection', value: '42%'),
              _LegendStat(label: 'Payouts', value: '31%'),
              _LegendStat(label: 'Reserve', value: '27%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool active;

  const _SegmentPill({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.cardWhite.withValues(alpha: 0.9)
            : AppTheme.darkSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? AppTheme.cardWhite.withValues(alpha: 0.22)
              : AppTheme.darkBorder.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  active ? AppTheme.darkBackground : AppTheme.darkTextTertiary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InsightsChart extends StatelessWidget {
  const _InsightsChart();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: const [
              Center(child: _ArcChart()),
              Positioned(
                  top: 36, left: 10, child: _ChartLabel(label: 'reserve')),
              Positioned(top: 96, left: 0, child: _ChartLabel(label: 'pool')),
              Positioned(
                  top: 38, right: 20, child: _ChartLabel(label: 'payouts')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArcChart extends StatelessWidget {
  const _ArcChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(220, 140),
      painter: _ArcChartPainter(),
    );
  }
}

class _ArcChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 14, size.width - 20, size.width - 20);
    const strokeWidth = 24.0;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.darkBorder;

    final reservePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.secondaryColor;

    final poolPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.darkTextTertiary;

    final payoutPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.accentYellow;

    canvas.drawArc(rect, math.pi * 0.82, math.pi * 0.22, false, basePaint);
    canvas.drawArc(rect, math.pi * 1.06, math.pi * 0.34, false, reservePaint);
    canvas.drawArc(rect, math.pi * 1.43, math.pi * 0.30, false, poolPaint);
    canvas.drawArc(rect, math.pi * 1.76, math.pi * 0.42, false, payoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChartLabel extends StatelessWidget {
  final String label;

  const _ChartLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.darkTextSecondary,
          ),
    );
  }
}

class _LegendStat extends StatelessWidget {
  final String label;
  final String value;

  const _LegendStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.darkTextTertiary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _ValueStrip extends StatelessWidget {
  final TextTheme textTheme;

  const _ValueStrip({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return _LandingPanel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          _ValuePill(
            textTheme: textTheme,
            title: 'Faster review',
            value: 'Desktop rail keeps wallet and notifications visible.',
          ),
          _ValuePill(
            textTheme: textTheme,
            title: 'Cleaner payouts',
            value:
                'Round status, rules, and history stay aligned on one screen.',
          ),
          _ValuePill(
            textTheme: textTheme,
            title: 'Calmer oversight',
            value: 'Less tab switching when you manage multiple equbs.',
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final TextTheme textTheme;
  final String title;
  final String value;

  const _ValuePill({
    required this.textTheme,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 390),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.darkBorder.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.labelLarge?.copyWith(
              color: AppTheme.darkAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.darkTextSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPanel extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _LandingPanel({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppTheme.darkBorder.withValues(alpha: 0.94),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkCard.withValues(alpha: 0.98),
            AppTheme.darkBackground.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: child,
    );
  }
}
