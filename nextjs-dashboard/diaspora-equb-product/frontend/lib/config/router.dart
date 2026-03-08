import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/desktop_landing_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/wallet_binding_screen.dart';
import '../screens/main_shell.dart';
import '../screens/pay_screen.dart';
import '../screens/receive_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/pool_browser_screen.dart';
import '../screens/pool_status_screen.dart';
import '../screens/payout_tracker_screen.dart';
import '../screens/credit_tier_screen.dart';
import '../screens/withdraw_screen.dart';
import '../screens/collateral_screen.dart';
import '../screens/fund_wallet_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/equb_insights_screen.dart';
import '../screens/equb_rules_screen.dart';
import '../screens/swap_screen.dart';
import '../screens/equb_governance_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/badges_screen.dart';
import '../screens/security_screen.dart';
import '../widgets/desktop_shell.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isEntryRoute = state.matchedLocation == '/';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isAuthRoute = state.matchedLocation == '/auth';
      final isBindingWallet = state.matchedLocation == '/bind-wallet';
      final hasCompletedOnboarding = authProvider.hasCompletedOnboarding;
      final isDesktopViewport = _isDesktopViewport(context);

      if (!hasCompletedOnboarding &&
          !isDesktopViewport &&
          !isEntryRoute &&
          !isOnboarding) {
        return '/';
      }

      if (isDesktopViewport && !isAuthenticated && isOnboarding) {
        return '/';
      }

      if (hasCompletedOnboarding &&
          !isAuthenticated &&
          !isDesktopViewport &&
          (isEntryRoute || isOnboarding)) {
        return '/auth';
      }

      if (isAuthenticated &&
          (isOnboarding ||
              isAuthRoute ||
              (!isDesktopViewport && isEntryRoute))) {
        return '/dashboard';
      }

      if (!isAuthenticated && isBindingWallet) {
        return '/auth';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'entry',
        builder: (context, state) {
          if (_isDesktopViewport(context)) {
            return const DesktopLandingScreen();
          }
          if (_isMobileAppPlatform()) {
            return const SplashScreen();
          }
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/bind-wallet',
        name: 'bind-wallet',
        builder: (context, state) => const WalletBindingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/pay',
        name: 'pay',
        builder: (context, state) => const PayScreen(),
      ),
      GoRoute(
        path: '/receive',
        name: 'receive',
        builder: (context, state) => const ReceiveScreen(),
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        builder: (context, state) => const TransactionsScreen(standalone: true),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => _wrapDesktopShell(
          context,
          section: DesktopShellSection.profile,
          child: const ProfileScreen(standalone: false),
          fallback: const ProfileScreen(standalone: true),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profile-edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/security',
        name: 'profile-security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/profile/help',
        name: 'profile-help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/pools',
        name: 'pools',
        builder: (context, state) => _wrapDesktopShell(
          context,
          section: DesktopShellSection.equbs,
          child: const PoolBrowserScreen(),
          fallback: Scaffold(
            appBar: AppBar(title: const Text('Equbs')),
            body: const PoolBrowserScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/pools/:id',
        name: 'pool-status',
        builder: (context, state) {
          final poolId = state.pathParameters['id']!;
          return _wrapDesktopShell(
            context,
            section: DesktopShellSection.equbs,
            child: PoolStatusScreen(poolId: poolId, embeddedDesktop: true),
            fallback: PoolStatusScreen(poolId: poolId),
          );
        },
      ),
      GoRoute(
        path: '/payouts/:poolId',
        name: 'payout-tracker',
        builder: (context, state) {
          final poolId = state.pathParameters['poolId']!;
          return _wrapDesktopShell(
            context,
            section: DesktopShellSection.equbs,
            child: PayoutTrackerScreen(poolId: poolId, embeddedDesktop: true),
            fallback: PayoutTrackerScreen(poolId: poolId),
          );
        },
      ),
      GoRoute(
        path: '/credit',
        name: 'credit',
        builder: (context, state) => const CreditTierScreen(),
      ),
      GoRoute(
        path: '/withdraw',
        name: 'withdraw',
        builder: (context, state) => const WithdrawScreen(standalone: true),
      ),
      GoRoute(
        path: '/collateral',
        name: 'collateral',
        builder: (context, state) => const CollateralScreen(),
      ),
      GoRoute(
        path: '/fund-wallet',
        name: 'fund-wallet',
        builder: (context, state) => const FundWalletScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/equb-insights',
        name: 'equb-insights',
        builder: (context, state) => const EqubInsightsScreen(),
      ),
      GoRoute(
        path: '/equb-rules/:id',
        name: 'equb-rules',
        builder: (context, state) {
          final equbId = state.pathParameters['id']!;
          return _wrapDesktopShell(
            context,
            section: DesktopShellSection.equbs,
            child: EqubRulesScreen(equbId: equbId, embeddedDesktop: true),
            fallback: EqubRulesScreen(equbId: equbId),
          );
        },
      ),
      GoRoute(
        path: '/equb-governance/:id',
        name: 'equb-governance',
        builder: (context, state) {
          final equbId = state.pathParameters['id']!;
          return _wrapDesktopShell(
            context,
            section: DesktopShellSection.equbs,
            child: EqubGovernanceScreen(equbId: equbId, embeddedDesktop: true),
            fallback: EqubGovernanceScreen(equbId: equbId),
          );
        },
      ),
      GoRoute(
        path: '/swap',
        name: 'swap',
        builder: (context, state) => _wrapDesktopShell(
          context,
          section: DesktopShellSection.swap,
          child: const SwapScreen(),
          fallback: const SwapScreen(),
        ),
      ),
      GoRoute(
        path: '/referral',
        name: 'referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/badges',
        name: 'badges',
        builder: (context, state) => const BadgesScreen(),
      ),
    ],
  );
}

bool _isDesktopViewport(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery != null) {
    return mediaQuery.size.width >= AppTheme.desktopBreakpoint;
  }
  return false;
}

bool _isMobileAppPlatform() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

Widget _wrapDesktopShell(
  BuildContext context, {
  required DesktopShellSection section,
  required Widget child,
  required Widget fallback,
}) {
  if (!_isDesktopViewport(context)) {
    return fallback;
  }

  return DesktopShellRouteFrame(
    activeSection: section,
    child: child,
  );
}
