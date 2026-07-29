import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';

abstract interface class NotificationsRepository {
  Future<NotificationsPage> list({int page = 1});

  Future<void> deleteAll();

  Future<void> delete(String id);

  Future<void> updateFirebaseToken(String token);
}
