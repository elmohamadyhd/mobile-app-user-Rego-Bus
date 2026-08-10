import 'package:go_router/go_router.dart';

import 'package:safaria/features/profile/presentation/profile_edit_screen.dart';
import 'package:safaria/features/profile/presentation/saved_travellers_screen.dart';
import 'package:safaria/features/profile/presentation/settings_screen.dart';

abstract final class ProfileRoutes {
  static const edit = '/profile/edit';
  static const savedTravellers = '/profile/saved-travellers';
  static const settings = '/profile/settings';
}

List<RouteBase> profileRoutes() => [
      GoRoute(
        path: ProfileRoutes.edit,
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: ProfileRoutes.savedTravellers,
        builder: (_, __) => const SavedTravellersScreen(),
      ),
      GoRoute(
        path: ProfileRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ];
