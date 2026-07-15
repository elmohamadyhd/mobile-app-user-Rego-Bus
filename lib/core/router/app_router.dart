import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/forgot_password_screen.dart';
import 'package:rego/features/auth/presentation/login_screen.dart';
import 'package:rego/features/auth/presentation/new_password_screen.dart';
import 'package:rego/features/auth/presentation/onboarding_screen.dart';
import 'package:rego/features/auth/presentation/otp_verify_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/register_screen.dart';
import 'package:rego/features/auth/presentation/splash_screen.dart';
import 'package:rego/features/home/presentation/home_screen.dart';
import 'package:rego/features/profile/presentation/profile_screen.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';

// Named route constants so call-sites never use raw strings.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const home = '/';
  static const tickets = '/tickets';
  static const profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          final args = state.extra;
          return LoginScreen(
            gateArgs: args is AuthGateArgs ? args : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          final args = state.extra;
          return RegisterScreen(
            gateArgs: args is AuthGateArgs ? args : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final args = state.extra;
          if (args is! OtpArgs) return const LoginScreen();
          return OtpVerifyScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ResetArgs) return const LoginScreen();
          return NewPasswordScreen(args: args);
        },
      ),
      // Signed-in tab shell. Each tab is a branch with preserved state; the
      // shell scaffold supplies the shared bottom nav bar. Full-screen flows
      // (booking below, auth above) stay on the root navigator and hide it.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                builder: (context, state) => const TicketsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      ...busRoutes(),
      ...walletRoutes(),
    ],
  );
});

/// Bridges the session state to go_router: notifies on auth changes (so the
/// guard re-runs) and decides redirects based on whether a session exists
/// or the user is browsing as a guest.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
    _ref.listen(guestModeProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  static const _authRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.otp,
    AppRoutes.forgotPassword,
    AppRoutes.newPassword,
  };

  String? redirect(BuildContext context, GoRouterState state) {
    final session = _ref.read(sessionControllerProvider);
    final guestMode = _ref.read(guestModeProvider);
    if (!session.hasValue || !guestMode.hasValue) {
      return null; // still resolving — splash waits.
    }

    final loggedIn = session.value != null;
    final isGuest = guestMode.value ?? false;
    final allowedInApp = loggedIn || isGuest;
    final at = state.matchedLocation;
    final atAuthRoute = _authRoutes.contains(at);

    // Signed-in users should not linger on auth screens; guests may open
    // login/register voluntarily (profile CTA, guest gate sheet).
    if (loggedIn && atAuthRoute && at != AppRoutes.splash) {
      return AppRoutes.home;
    }
    if (!allowedInApp && !atAuthRoute) {
      return AppRoutes.login;
    }
    return null;
  }
}
