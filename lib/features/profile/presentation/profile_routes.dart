import 'package:go_router/go_router.dart';

import 'package:safaria/features/profile/presentation/profile_edit_screen.dart';

abstract final class ProfileRoutes {
  static const edit = '/profile/edit';
}

List<RouteBase> profileRoutes() => [
      GoRoute(
        path: ProfileRoutes.edit,
        builder: (_, __) => const ProfileEditScreen(),
      ),
    ];
