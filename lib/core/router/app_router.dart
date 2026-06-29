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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
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
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

/// Bridges the session state to go_router: notifies on auth changes (so the
/// guard re-runs) and decides redirects based on whether a session exists.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
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
    final loc = state.matchedLocation;

    // Hold on the splash until the persisted session resolves.
    if (session.isLoading || !session.hasValue) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final authed = session.requireValue != null;
    final onAuthRoute = _authRoutes.contains(loc);

    if (!authed && !onAuthRoute) return AppRoutes.login;
    if (authed && onAuthRoute) return AppRoutes.home;
    return null;
  }
}
