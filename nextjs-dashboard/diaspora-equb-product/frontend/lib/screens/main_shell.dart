import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';
import 'withdraw_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // Start on Home (center tab)

  final List<Widget> _screens = const [
    TransactionsScreen(standalone: false),
    HomeScreen(),
    WithdrawScreen(),
  ];

  /// Breakpoint for switching to wide (desktop/tablet) layout.
  static const double _wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _wideBreakpoint) {
                return _buildWideLayout(constraints);
              }
              return _buildMobileLayout();
            },
          ),
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            // Hide bottom nav on wide screens (sidebar is used instead)
            if (MediaQuery.of(context).size.width >= _wideBreakpoint) {
              return const SizedBox.shrink();
            }
            return _buildBottomNav();
          },
        ),
      ),
    );
  }

  // ── Mobile layout ──────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return IndexedStack(
      index: _currentIndex,
      children: _screens,
    );
  }

  // ── Wide / desktop layout ──────────────────────────────────────────
  Widget _buildWideLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Sidebar navigation
        _buildSideNav(),
        // Main content area – scrollable columns
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: _buildWideContent(constraints),
          ),
        ),
      ],
    );
  }

  Widget _buildWideContent(BoxConstraints constraints) {
    // Available width after sidebar (~72px)
    final contentWidth = constraints.maxWidth - 72;

    // For very wide screens, show all three columns
    if (contentWidth >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Home
          Expanded(
            flex: 3,
            child: _screens[1], // HomeScreen
          ),
          const SizedBox(width: 12),
          // Middle column: Transactions
          Expanded(
            flex: 3,
            child: _screens[0], // TransactionsScreen
          ),
          const SizedBox(width: 12),
          // Right column: Withdraw
          Expanded(
            flex: 3,
            child: _screens[2], // WithdrawScreen
          ),
        ],
      );
    }

    // For medium-wide, show two columns
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _screens[_currentIndex],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _screens[(_currentIndex + 1) % 3],
        ),
      ],
    );
  }

  // ── Side navigation (wide screens) ─────────────────────────────────
  Widget _buildSideNav() {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // App logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.darkButton,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.spa_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 32),
          // Nav items
          _buildSideNavItem(
            index: 1,
            icon: Icons.home_rounded,
            isActive: _currentIndex == 1,
          ),
          const SizedBox(height: 8),
          _buildSideNavItem(
            index: 0,
            icon: Icons.swap_horiz_rounded,
            isActive: _currentIndex == 0,
          ),
          const SizedBox(height: 8),
          _buildSideNavItem(
            index: 2,
            icon: Icons.account_balance_wallet_outlined,
            isActive: _currentIndex == 2,
          ),
          const Spacer(),
          // Bottom icons
          _buildSideNavIcon(Icons.account_balance_wallet_outlined),
          const SizedBox(height: 8),
          _buildSideNavIcon(Icons.settings_outlined),
        ],
      ),
    );
  }

  Widget _buildSideNavItem({
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
          shape: BoxShape.circle,
          color: isActive
              ? AppTheme.darkButton
              : AppTheme.cardWhite.withValues(alpha: 0.5),
          border: isActive
              ? null
              : Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSideNavIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardWhite.withValues(alpha: 0.4),
        border: Border.all(
          color: AppTheme.textPrimary.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Icon(icon, size: 22, color: AppTheme.textPrimary),
    );
  }

  // ── Bottom navigation (mobile) ─────────────────────────────────────
  Widget _buildBottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.swap_horiz_rounded,
              isActive: _currentIndex == 0,
            ),
            const SizedBox(width: 2),
            _buildNavItem(
              index: 1,
              icon: Icons.home_rounded,
              isActive: _currentIndex == 1,
            ),
            const SizedBox(width: 2),
            _buildNavItem(
              index: 2,
              icon: Icons.account_balance_wallet_outlined,
              isActive: _currentIndex == 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppTheme.darkButton
              : AppTheme.cardWhite.withValues(alpha: 0.5),
          border: isActive
              ? null
              : Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.darkButton.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
