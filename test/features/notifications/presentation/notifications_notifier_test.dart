import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/notifications/domain/entities/app_notification.dart';
import 'package:safaria/features/notifications/presentation/providers/notifications_providers.dart';

import '../fake_notifications_repository.dart';

void main() {
  const unread = AppNotification(
    id: 'a',
    title: 'T1',
    description: 'D1',
    createdDate: '1',
    formattedDate: '1',
  );
  final read = AppNotification(
    id: 'b',
    title: 'T2',
    description: 'D2',
    createdDate: '2',
    formattedDate: '2',
    readAt: DateTime.utc(2026, 7, 2, 10, 56, 45),
  );

  ProviderContainer makeContainer(FakeNotificationsRepository repo) {
    final container = ProviderContainer(
      overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('NotificationsNotifier', () {
    test('build loads the first page', () async {
      final repo = FakeNotificationsRepository(items: [unread, read]);
      final container = makeContainer(repo);

      final page = await container.read(notificationsProvider.future);

      expect(page.items.length, 2);
      expect(repo.listCallCount, 1);
    });

    test('delete removes item optimistically', () async {
      final repo = FakeNotificationsRepository(items: [unread, read]);
      final container = makeContainer(repo);
      await container.read(notificationsProvider.future);

      await container.read(notificationsProvider.notifier).delete('a');

      final page = container.read(notificationsProvider).value!;
      expect(page.items.map((n) => n.id), ['b']);
      expect(repo.deleteCallCount, 1);
    });

    test('delete rolls back when the API fails', () async {
      final repo = FakeNotificationsRepository(items: [unread, read])
        ..deleteShouldThrow = true;
      final container = makeContainer(repo);
      await container.read(notificationsProvider.future);

      await expectLater(
        container.read(notificationsProvider.notifier).delete('a'),
        throwsA(isA<Exception>()),
      );

      final page = container.read(notificationsProvider).value!;
      expect(page.items.map((n) => n.id), ['a', 'b']);
    });

    test('clearAll empties the list', () async {
      final repo = FakeNotificationsRepository(items: [unread, read]);
      final container = makeContainer(repo);
      await container.read(notificationsProvider.future);

      await container.read(notificationsProvider.notifier).clearAll();

      final page = container.read(notificationsProvider).value!;
      expect(page.items, isEmpty);
      expect(repo.deleteAllCallCount, 1);
    });

    test('loadMore appends the next page', () async {
      final repo = FakeNotificationsRepository(items: [unread], lastPage: 2);
      final container = makeContainer(repo);
      await container.read(notificationsProvider.future);

      await container.read(notificationsProvider.notifier).loadMore();

      final page = container.read(notificationsProvider).value!;
      expect(page.items.map((n) => n.id), ['a', 'page2']);
      expect(page.currentPage, 2);
    });
  });
}
