import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/notifications/data/notifications_api.dart';
import 'package:safaria/features/notifications/data/notifications_repository_impl.dart';
import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';
import 'package:safaria/features/notifications/domain/repositories/notifications_repository.dart';

final notificationsApiProvider =
    Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(dioProvider)));

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(ref.watch(notificationsApiProvider)),
);

class NotificationsNotifier extends AsyncNotifier<NotificationsPage> {
  @override
  Future<NotificationsPage> build() =>
      ref.read(notificationsRepositoryProvider).list(page: 1);

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).list(page: 1),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNextPage) return;
    final nextPage = current.currentPage + 1;
    final next =
        await ref.read(notificationsRepositoryProvider).list(page: nextPage);
    state = AsyncData(current.append(next));
  }

  Future<void> delete(String id) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(previous.withoutId(id));
    }
    try {
      await ref.read(notificationsRepositoryProvider).delete(id);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> clearAll() async {
    await ref.read(notificationsRepositoryProvider).deleteAll();
    state = const AsyncData(NotificationsPage.empty);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsPage>(
  NotificationsNotifier.new,
);

/// Whether the home bell should show an unread amber dot.
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final guest = ref.watch(guestModeProvider).value;
  if (guest != false) return false;
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) return false;

  final async = ref.watch(notificationsProvider);
  return async.maybeWhen(
    data: (page) => page.items.any((n) => n.isUnread),
    orElse: () => false,
  );
});
