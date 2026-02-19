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
      // ── Auth flow ────────────────────────────────────────────────
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

      // ── Main app (bottom nav shell) ──────────────────────────────
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainShell(),
      ),

      // ── Standalone screens ───────────────────────────────────────
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

      // ── Existing equb screens ────────────────────────────────────
      GoRoute(
        path: '/pools',
        name: 'pools',
        builder: (context, state) => const PoolBrowserScreen(),
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
    ],
  );
}
