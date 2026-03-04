import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/wallet_provider.dart';
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

  static const double _wideBreakpoint = 840.0;
  static const double _dashboardBreakpoint = 1024.0;

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
              if (constraints.maxWidth >= _wideBreakpoint) {
                return _buildWideLayout(constraints);
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

  Widget _buildWideLayout(BoxConstraints constraints) {
    final showDashboard =
        _currentIndex == 0 && constraints.maxWidth >= _dashboardBreakpoint;

    return Row(
      children: [
        _buildSideNav(),
        if (showDashboard)
          ..._buildDashboardColumns()
        else
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildDashboardColumns() {
    return [
      const Expanded(
        flex: 4,
        child: HomeScreen(desktopMode: DesktopHomeMode.leftPanel),
      ),
      const SizedBox(width: 2),
      const Expanded(
        flex: 3,
        child: HomeScreen(desktopMode: DesktopHomeMode.middlePanel),
      ),
      const SizedBox(width: 2),
      Expanded(
        flex: 3,
        child: _DesktopPayPanel(),
      ),
    ];
  }

  Widget _buildSideNav() {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.buttonColor(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.spa_rounded, size: 22, color: AppTheme.buttonTextColor(context)),
          ),
          const SizedBox(height: 32),
          for (int i = 0; i < _navItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildSideNavItem(
              index: i,
              icon: _navItems[i].icon,
              isActive: _currentIndex == i,
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 3),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.3),
                border: Border.all(color: AppTheme.cardColor(context), width: 2),
              ),
              child: const Icon(Icons.person, size: 20, color: Colors.white70),
            ),
          ),
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
              ? AppTheme.buttonColor(context)
              : AppTheme.cardColor(context).withValues(alpha: 0.5),
          border: isActive
              ? null
              : Border.all(
                  color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.1),
                  width: 1.5,
                ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? AppTheme.buttonTextColor(context) : AppTheme.textPrimaryColor(context),
        ),
      ),
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
                      color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.1),
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
              color: isActive ? AppTheme.buttonTextColor(context) : AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppTheme.textPrimaryColor(context) : AppTheme.textTertiaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPayPanel extends StatefulWidget {
  @override
  State<_DesktopPayPanel> createState() => _DesktopPayPanelState();
}

class _DesktopPayPanelState extends State<_DesktopPayPanel> {
  final _recipientController = TextEditingController();
  String _amount = '0';

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    setState(() {
      if (_amount == '0' && digit != '.') {
        _amount = digit;
      } else {
        if (digit == '.' && _amount.contains('.')) return;
        _amount += digit;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final balance = double.tryParse(wallet.balance) ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 24),
      child: Column(
        children: [
          _buildRecipientSection(context),
          const SizedBox(height: 24),
          Text(
            '\$$_amount',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Balance: \$${balance.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor(context)),
          ),
          const SizedBox(height: 16),
          _buildTransferInfo(wallet),
          const SizedBox(height: 20),
          _buildNumpad(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.push('/pay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor(context),
                foregroundColor: AppTheme.buttonTextColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text('Send', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.2),
            ),
            child: Icon(Icons.person, size: 20, color: AppTheme.textSecondaryColor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _recipientController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Recipient address (0x...)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text('Change',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.positive)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferInfo(WalletProvider wallet) {
    final balance = double.tryParse(wallet.balance) ?? 0.0;
    final amountNum = double.tryParse(_amount) ?? 0.0;
    final remaining = balance - amountNum;

    String eurRate = '0.95';
    if (wallet.rates.containsKey('EUR')) {
      eurRate = wallet.rates['EUR']!.toStringAsFixed(2);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow('Exchange rate', '1 USD = $eurRate EUR'),
          const SizedBox(height: 6),
          _infoRow('Balance after transfer', '\$${remaining.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _infoRow('Transaction fee', '\$0.00 (free transfer)'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryColor(context))),
      ],
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _numpadRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _numpadRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _numpadRow(['7', '8', '9']),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _numpadButton('.')),
            const SizedBox(width: 10),
            Expanded(child: _numpadButton('0')),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _onBackspace,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(Icons.backspace_outlined, size: 22, color: AppTheme.textPrimaryColor(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Row _numpadRow(List<String> digits) {
    return Row(
      children: digits.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 10 : 0),
            child: _numpadButton(e.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _numpadButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
