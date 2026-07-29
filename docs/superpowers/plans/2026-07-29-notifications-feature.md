# Notifications Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Authenticated notification inbox (list, clear-all, swipe-delete) plus push-token sync via `PUT /profile/firebase/token`, wired from the home bell.

**Architecture:** Standalone `lib/features/notifications/` slice (domain → data → Riverpod → UI), mirroring addresses. Push token uses `PushTokenProvider` backed by the existing install UUID until Firebase project files exist.

**Tech Stack:** Flutter, Riverpod, Dio, Freezed, go_router, Phosphor icons, ARB l10n.

## Global Constraints

- Package imports only (`package:safaria/...`).
- No hardcoded user-facing strings; ARB keys in both `app_en.arb` and `app_ar.arb`.
- Design tokens only (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`).
- Icons: `PhosphorIconsLight.*` only.
- Directional insets (`EdgeInsetsDirectional`); RTL-safe back chevron flip.
- Scrollable bodies; no fixed layout widths.
- Do **not** add `firebase_core` / `firebase_messaging` in this plan.
- Delete-by-id path: `DELETE /profile/notifications/:id`.
- Clear-all path: `DELETE /profile/notifications`.
- Token body field: `firebase_token` (form-data / Map for Dio).

---

## File structure

| Path | Responsibility |
|------|----------------|
| `lib/features/notifications/domain/entities/app_notification.dart` | Freezed entity |
| `lib/features/notifications/domain/entities/notifications_page.dart` | Paginated list |
| `lib/features/notifications/domain/repositories/notifications_repository.dart` | Abstract repo |
| `lib/features/notifications/data/notifications_api.dart` | Dio calls |
| `lib/features/notifications/data/notifications_dto_mapper.dart` | JSON → domain |
| `lib/features/notifications/data/notifications_repository_impl.dart` | Repo impl |
| `lib/features/notifications/presentation/providers/notifications_providers.dart` | List notifier + unread |
| `lib/features/notifications/presentation/providers/push_token_provider.dart` | Token source |
| `lib/features/notifications/presentation/providers/fcm_registrar.dart` | Auth → PUT token |
| `lib/features/notifications/presentation/notifications_routes.dart` | go_router routes |
| `lib/features/notifications/presentation/notifications_screen.dart` | Inbox screen |
| `lib/features/notifications/presentation/widgets/*` | App bar, card, section header |
| `test/features/notifications/**` | Mapper + notifier tests |

---

### Task 1: Domain + mapper + API + repository (TDD)

**Files:**
- Create: domain/data files listed above
- Test: `test/features/notifications/data/notifications_dto_mapper_test.dart`

**Interfaces:**
- Produces: `AppNotification`, `NotificationsPage`, `NotificationsRepository`, `NotificationsApi`, `NotificationsDtoMapper`, `NotificationsRepositoryImpl`

- [ ] **Step 1: Write failing mapper test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/notifications/data/notifications_dto_mapper.dart';

void main() {
  test('pageFromEnvelope maps unread and read items', () {
    final page = NotificationsDtoMapper.pageFromEnvelope({
      'data': [
        {
          'id': 'a',
          'title': 'T1',
          'description': 'D1',
          'created_date': '2026-07-02 12:48:02',
          'formatted_date': '2026-07-02 12:48 pm',
          'data': {},
          'read_at': null,
        },
        {
          'id': 'b',
          'title': 'T2',
          'description': 'D2',
          'created_date': '2026-07-02 12:46:05',
          'formatted_date': '2026-07-02 12:46 pm',
          'data': {'x': 1},
          'read_at': '2026-07-02T10:56:45.000000Z',
        },
      ],
      'pagination': {
        'total': 2,
        'lastPage': 1,
        'perPage': 15,
        'currentPage': 1,
      },
    });
    expect(page.items.length, 2);
    expect(page.items[0].isUnread, isTrue);
    expect(page.items[1].isUnread, isFalse);
    expect(page.currentPage, 1);
    expect(page.hasNextPage, isFalse);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL** (mapper missing)

Run: `flutter test test/features/notifications/data/notifications_dto_mapper_test.dart`

- [ ] **Step 3: Implement domain + mapper + API + repo**

`app_notification.dart` (Freezed + `isUnread` via private constructor extension on the freezed class):

```dart
@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();
  const factory AppNotification({
    required String id,
    required String title,
    required String description,
    required String createdDate,
    required String formattedDate,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    DateTime? readAt,
  }) = _AppNotification;

  bool get isUnread => readAt == null;
}
```

`notifications_page.dart` — copy `AddressPage` pattern with `AppNotification`.

`NotificationsRepository`:

```dart
abstract class NotificationsRepository {
  Future<NotificationsPage> list({int page = 1});
  Future<void> deleteAll();
  Future<void> delete(String id);
  Future<void> updateFirebaseToken(String token);
}
```

`NotificationsApi`:

```dart
Future<dynamic> list({int page = 1}) =>
  _dio.get('/profile/notifications', queryParameters: {'page': page})
      .then((r) => r.data);

Future<void> deleteAll() => _dio.delete('/profile/notifications');

Future<void> delete(String id) =>
  _dio.delete('/profile/notifications/$id');

Future<void> updateFirebaseToken(String token) =>
  _dio.put('/profile/firebase/token', data: {'firebase_token': token});
```

Mapper parses `read_at` with `DateTime.tryParse`. Repo impl delegates + maps.

- [ ] **Step 4: Run `dart run build_runner build --delete-conflicting-outputs`** for Freezed

- [ ] **Step 5: Run mapper test — PASS**

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications/domain lib/features/notifications/data \
  test/features/notifications/data
git commit -m "feat(notifications): add domain, API, and DTO mapper"
```

---

### Task 2: Providers (list notifier + unread + push token + registrar)

**Files:**
- Create: `presentation/providers/notifications_providers.dart`
- Create: `presentation/providers/push_token_provider.dart`
- Create: `presentation/providers/fcm_registrar.dart`
- Test: `test/features/notifications/presentation/notifications_notifier_test.dart`

**Interfaces:**
- Consumes: `NotificationsRepository`
- Produces: `notificationsProvider`, `hasUnreadNotificationsProvider`,
  `pushTokenProvider`, `fcmRegistrarProvider`

- [ ] **Step 1: Write failing notifier test** with fake repository (in-memory list)

Cover: initial load, `delete`, `clearAll`, `loadMore` append.

- [ ] **Step 2: Implement providers** mirroring `AddressesNotifier`;
  `hasUnreadNotificationsProvider` returns false when
  `guestModeProvider.value != false`, else watches `notificationsProvider` and
  checks `items.any((n) => n.isUnread)`.

`DevicePushTokenProvider` calls `secureStorage.readOrCreateDeviceToken()`.

`fcmRegistrarProvider` = `Provider<void>` that:
- reads session + guest
- if authenticated and not guest: async unawaited register
- on failure: ignore (optionally `debugPrint`)

- [ ] **Step 3: Tests PASS**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(notifications): add list notifier and push token registrar"
```

---

### Task 3: l10n keys

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

Keys (English + Arabic + `@` descriptions on en):

- `notificationsScreenTitle` — Notifications / الإشعارات
- `notificationsClearAll` — Clear all / مسح الكل
- `notificationsClearAllConfirmTitle` — Clear all notifications? / مسح كل الإشعارات؟
- `notificationsClearAllConfirmBody` — This cannot be undone. / لا يمكن التراجع عن هذا الإجراء.
- `notificationsClearAllConfirmAction` — Clear / مسح
- `notificationsCancel` — Cancel / إلغاء
- `notificationsSectionNew` — New / جديد
- `notificationsSectionEarlier` — Earlier / سابق
- `notificationsEmptyTitle` — No notifications yet / لا توجد إشعارات بعد
- `notificationsEmptySubtitle` — Updates about your trips will show up here / ستظهر هنا التحديثات المتعلقة برحلاتك
- `notificationsError` — Couldn’t load notifications / تعذر تحميل الإشعارات
- `notificationsRetry` — Retry / إعادة المحاولة
- `notificationsDeleteFailed` — Couldn’t delete notification / تعذر حذف الإشعار
- `notificationsClearFailed` — Couldn’t clear notifications / تعذر مسح الإشعارات

- [ ] **Step 1: Add keys to both ARBs**

- [ ] **Step 2: `flutter gen-l10n`**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(notifications): add localization strings"
```

---

### Task 4: UI screen + widgets + routes

**Files:**
- Create: widgets + `notifications_screen.dart` + `notifications_routes.dart`
- Modify: `lib/core/router/app_router.dart` — spread `notificationsRoutes()`
- Test: optional widget smoke `test/features/notifications/presentation/notifications_screen_test.dart`

**Interfaces:**
- Produces: `NotificationsRoutes.list = '/profile/notifications'`

Screen behavior per spec § UI. Use `Dismissible` for swipe delete
(`direction: DismissDirection.endToStart`). Clear-all `TextButton` in app bar.

- [ ] **Step 1: Implement widgets + screen + routes**

- [ ] **Step 2: Register routes in `app_router.dart`**

- [ ] **Step 3: `flutter analyze` on notifications paths — clean**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(notifications): add inbox screen and routes"
```

---

### Task 5: Home bell + badge + registrar watch

**Files:**
- Modify: `lib/shared/widgets/skyline_tab_hero.dart` — add `showBadge` (default `true` for backward compat, home passes explicit value)
- Modify: `lib/features/home/presentation/home_screen.dart` — wire onTap + badge
- Modify: `lib/app.dart` — `ref.watch(fcmRegistrarProvider)` inside a small listener widget or existing root

Guest: `context.go(AppRoutes.login, extra: AuthGateArgs(returnTo: NotificationsRoutes.list))`.

- [ ] **Step 1: Implement wiring**

- [ ] **Step 2: Analyze + run relevant tests**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(notifications): wire home bell and push token sync"
```

---

### Task 6: Spec/plan already on branch — final verify

- [ ] **Step 1: `flutter analyze`**
- [ ] **Step 2: `flutter test test/features/notifications/`**
- [ ] **Step 3: Fix any failures**

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| List + pagination | 1, 2, 4 |
| Clear all + confirm | 3, 4 |
| Swipe delete by id | 1, 4 |
| New / Earlier + unread dot | 4 |
| No tap navigation | 4 |
| Home bell + guest gate | 5 |
| Unread badge | 2, 5 |
| Token PUT sync | 1, 2, 5 |
| No firebase packages | Global |
| l10n / RTL / tokens | 3, 4 |
| Tests | 1, 2, 6 |
