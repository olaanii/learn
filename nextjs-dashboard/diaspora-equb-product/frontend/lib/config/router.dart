import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/onboarding_screen.dart';
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

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isOnboarding = state.matchedLocation == '/';
      final isBindingWallet = state.matchedLocation == '/bind-wallet';

      if (!isAuthenticated && !isOnboarding) {
        return '/';
      }

      if (isAuthenticated &&
          authProvider.status == AuthStatus.authenticated &&
          !isBindingWallet &&
          isOnboarding) {
        return '/bind-wallet';
      }

      if (authProvider.status == AuthStatus.walletBound &&
          (isOnboarding || isBindingWallet)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
        builder: (context, state) =>
            const TransactionsScreen(standalone: true),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(standalone: true),
      ),
      GoRoute(
        path: '/pools',
        name: 'pools',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Equbs')),
          body: const PoolBrowserScreen(),
        ),
      ),
      GoRoute(
        path: '/pools/:id',
        name: 'pool-status',
        builder: (context, state) {
          final poolId = state.pathParameters['id']!;
          return PoolStatusScreen(poolId: poolId);
        },
      ),
      GoRoute(
        path: '/payouts/:poolId',
        name: 'payout-tracker',
        builder: (context, state) {
          final poolId = state.pathParameters['poolId']!;
          return PayoutTrackerScreen(poolId: poolId);
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
        builder: (context, state) =>
            const WithdrawScreen(standalone: true),
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
          return EqubRulesScreen(equbId: equbId);
        },
      ),
      GoRoute(
        path: '/equb-governance/:id',
        name: 'equb-governance',
        builder: (context, state) {
          final equbId = state.pathParameters['id']!;
          return EqubGovernanceScreen(equbId: equbId);
        },
      ),
      GoRoute(
        path: '/swap',
        name: 'swap',
        builder: (context, state) => const SwapScreen(),
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
