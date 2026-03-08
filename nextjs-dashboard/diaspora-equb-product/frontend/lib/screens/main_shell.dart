import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../widgets/desktop_layout.dart';
import '../widgets/desktop_shell.dart';
import 'home_screen.dart';
import 'pool_browser_screen.dart';
import 'swap_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PoolBrowserScreen(),
    SwapScreen(),
    ProfileScreen(standalone: false),
  ];

  static const double _wideBreakpoint = AppTheme.wideBreakpoint;
  static const double _desktopBreakpoint = AppTheme.desktopBreakpoint;

  static const List<_NavItemData> _navItems = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.groups_rounded, label: 'Equbs'),
    _NavItemData(icon: Icons.swap_horiz_rounded, label: 'Swap'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _desktopBreakpoint) {
                return _buildDesktopLayout(constraints);
              }
              if (constraints.maxWidth >= _wideBreakpoint) {
                return _buildWideLayout();
              }
              return _buildMobileLayout();
            },
          ),
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            if (MediaQuery.of(context).size.width >= _wideBreakpoint) {
              return const SizedBox.shrink();
            }
            return _buildBottomNav();
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return IndexedStack(
      index: _currentIndex,
      children: _screens,
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildWideSideNav(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Container(
                color: AppTheme.cardColor(context).withValues(alpha: 0.18),
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final showDashboard = _currentIndex == 0;

    return DesktopAppShell(
      activeSection: _sectionForIndex(_currentIndex),
      onSectionSelected: (section) {
        setState(() => _currentIndex = _indexForSection(section));
      },
      child: showDashboard
          ? _buildDesktopDashboard()
          : DesktopContent(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
    );
  }

  Widget _buildWideSideNav() {
    return Container(
      width: AppTheme.desktopRailWidth,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
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
          const SizedBox(height: 28),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < _navItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildWideSideNavItem(
                    index: i,
                    icon: _navItems[i].icon,
                    isActive: _currentIndex == i,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideSideNavItem({
    required int index,
    required IconData icon,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.buttonColor(context) : Colors.transparent,
          shape: BoxShape.circle,
          border: isActive
              ? null
              : Border.all(
                  color: AppTheme.textPrimaryColor(context)
                      .withValues(alpha: 0.08),
                  width: 1,
                ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? AppTheme.buttonTextColor(context)
              : AppTheme.textPrimaryColor(context),
        ),
      ),
    );
  }

  DesktopShellSection _sectionForIndex(int index) {
    switch (index) {
      case 1:
        return DesktopShellSection.equbs;
      case 2:
        return DesktopShellSection.swap;
      case 3:
        return DesktopShellSection.profile;
      case 0:
      default:
        return DesktopShellSection.home;
    }
  }

  int _indexForSection(DesktopShellSection section) {
    switch (section) {
      case DesktopShellSection.home:
        return 0;
      case DesktopShellSection.equbs:
        return 1;
      case DesktopShellSection.swap:
        return 2;
      case DesktopShellSection.profile:
        return 3;
    }
  }

  Widget _buildDesktopDashboard() {
    return const DesktopContent(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
      maxWidth: 1520,
      child: HomeScreen(desktopMode: DesktopHomeMode.unifiedDesktop),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < _navItems.length; i++)
              _buildNavItem(
                index: i,
                icon: _navItems[i].icon,
                label: _navItems[i].label,
                isActive: _currentIndex == i,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    final btnColor = AppTheme.buttonColor(context);
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? btnColor
                  : AppTheme.cardColor(context).withValues(alpha: 0.5),
              border: isActive
                  ? null
                  : Border.all(
                      color: AppTheme.textPrimaryColor(context)
                          .withValues(alpha: 0.1),
                      width: 1.5,
                    ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: btnColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? AppTheme.buttonTextColor(context)
                  : AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppTheme.textPrimaryColor(context)
                  : AppTheme.textTertiaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
