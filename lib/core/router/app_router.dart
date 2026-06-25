import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app_skeleton/features/home/presentation/home_screen.dart';

// Add named route constants here so call-sites never use raw strings.
abstract final class AppRoutes {
  static const home = '/';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      // Add routes here as you add features.
    ],
  );
});
