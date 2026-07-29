import 'package:safaria/features/notifications/domain/entities/app_notification.dart';

final class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasNextPage => currentPage < lastPage;

  NotificationsPage append(NotificationsPage next) => NotificationsPage(
        items: [...items, ...next.items],
        currentPage: next.currentPage,
        lastPage: next.lastPage,
        total: next.total,
      );

  NotificationsPage withoutId(String id) => NotificationsPage(
        items: items.where((n) => n.id != id).toList(growable: false),
        currentPage: currentPage,
        lastPage: lastPage,
        total: total > 0 ? total - 1 : 0,
      );

  static const empty = NotificationsPage(
    items: [],
    currentPage: 1,
    lastPage: 1,
    total: 0,
  );
}
