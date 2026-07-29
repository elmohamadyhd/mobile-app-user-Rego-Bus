import 'package:safaria/features/notifications/domain/entities/app_notification.dart';
import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';
import 'package:safaria/features/notifications/domain/repositories/notifications_repository.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    List<AppNotification>? items,
    this.lastPage = 1,
  }) : _items = List<AppNotification>.from(items ?? const []);

  final List<AppNotification> _items;
  int lastPage;
  int listCallCount = 0;
  int deleteCallCount = 0;
  int deleteAllCallCount = 0;
  int updateTokenCallCount = 0;
  String? lastToken;
  bool listShouldThrow = false;
  bool deleteShouldThrow = false;

  @override
  Future<NotificationsPage> list({int page = 1}) async {
    listCallCount++;
    if (listShouldThrow) throw Exception('list failed');
    if (page > 1) {
      return NotificationsPage(
        items: const [
          AppNotification(
            id: 'page2',
            title: 'P2',
            description: 'D',
            createdDate: '2',
            formattedDate: '2',
          ),
        ],
        currentPage: page,
        lastPage: lastPage,
        total: _items.length + 1,
      );
    }
    return NotificationsPage(
      items: List.unmodifiable(_items),
      currentPage: 1,
      lastPage: lastPage,
      total: _items.length,
    );
  }

  @override
  Future<void> delete(String id) async {
    deleteCallCount++;
    if (deleteShouldThrow) throw Exception('delete failed');
    _items.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCallCount++;
    _items.clear();
  }

  @override
  Future<void> updateFirebaseToken(String token) async {
    updateTokenCallCount++;
    lastToken = token;
  }
}
