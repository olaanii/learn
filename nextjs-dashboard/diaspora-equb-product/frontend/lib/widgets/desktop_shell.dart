import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/wallet_provider.dart';

enum DesktopShellSection { home, equbs, swap, profile }

class DesktopAppShell extends StatelessWidget {
  final DesktopShellSection activeSection;
  final ValueChanged<DesktopShellSection> onSectionSelected;
  final Widget child;

  const DesktopAppShell({
    super.key,
    required this.activeSection,
    required this.onSectionSelected,
    required this.child,
  });

  static const List<_DesktopNavItemData> _navItems = [
    _DesktopNavItemData(
      section: DesktopShellSection.home,
      icon: Icons.home_rounded,
      label: 'Home',
    ),
    _DesktopNavItemData(
      section: DesktopShellSection.equbs,
      icon: Icons.groups_rounded,
      label: 'Equbs',
    ),
    _DesktopNavItemData(
      section: DesktopShellSection.swap,
      icon: Icons.swap_horiz_rounded,
      label: 'Swap',
    ),
    _DesktopNavItemData(
      section: DesktopShellSection.profile,
      icon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DesktopSideNav(
          activeSection: activeSection,
          onSectionSelected: onSectionSelected,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 24, 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context).withValues(alpha: 0.22),
                  border: AppTheme.borderFor(context, opacity: 0.04),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DesktopShellRouteFrame extends StatelessWidget {
  final DesktopShellSection activeSection;
  final Widget child;

  const DesktopShellRouteFrame({
    super.key,
    required this.activeSection,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: DesktopAppShell(
            activeSection: activeSection,
            onSectionSelected: (section) =>
                _handleSectionNavigation(context, section),
            child: child,
          ),
        ),
      ),
    );
  }

  void _handleSectionNavigation(
      BuildContext context, DesktopShellSection section) {
    switch (section) {
      case DesktopShellSection.home:
        context.go('/dashboard');
        break;
      case DesktopShellSection.equbs:
        context.go('/pools');
        break;
      case DesktopShellSection.swap:
        context.go('/swap');
        break;
      case DesktopShellSection.profile:
        context.go('/profile');
        break;
    }
  }
}

class _DesktopSideNav extends StatelessWidget {
  final DesktopShellSection activeSection;
  final ValueChanged<DesktopShellSection> onSectionSelected;

  const _DesktopSideNav({
    required this.activeSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final panelColor = AppTheme.cardColor(context).withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.52,
    );

    return Container(
      width: AppTheme.desktopSidebarWidth,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: AppTheme.subtleShadowFor(context),
                  border: AppTheme.borderFor(context, opacity: 0.04),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.buttonColor(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diaspora Equb',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Desktop Workspace',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textTertiaryColor(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in DesktopAppShell._navItems) ...[
                    if (item != DesktopAppShell._navItems.first)
                      const SizedBox(height: 8),
                    _DesktopSideNavItem(
                      data: item,
                      isActive: activeSection == item.section,
                      onTap: () => onSectionSelected(item.section),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
              boxShadow: AppTheme.subtleShadowFor(context),
              border: AppTheme.borderFor(context, opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Snapshot',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${wallet.balance}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => onSectionSelected(DesktopShellSection.profile),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.textTertiaryColor(context)
                              .withValues(alpha: 0.25),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Open profile',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textTertiaryColor(context),
                      ),
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
}

class _DesktopSideNavItem extends StatelessWidget {
  final _DesktopNavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _DesktopSideNavItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.buttonColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? null
              : Border.all(
                  color: AppTheme.textPrimaryColor(context)
                      .withValues(alpha: 0.08),
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            Icon(
              data.icon,
              size: 22,
              color: isActive
                  ? AppTheme.buttonTextColor(context)
                  : AppTheme.textPrimaryColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isActive
                          ? AppTheme.buttonTextColor(context)
                          : AppTheme.textPrimaryColor(context),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavItemData {
  final DesktopShellSection section;
  final IconData icon;
  final String label;

  const _DesktopNavItemData({
    required this.section,
    required this.icon,
    required this.label,
  });
}
