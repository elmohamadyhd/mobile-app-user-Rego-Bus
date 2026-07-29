import 'package:go_router/go_router.dart';

import 'package:safaria/features/notifications/presentation/notifications_screen.dart';

abstract final class NotificationsRoutes {
  static const list = '/profile/notifications';
}

List<RouteBase> notificationsRoutes() => [
      GoRoute(
        path: NotificationsRoutes.list,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ];
