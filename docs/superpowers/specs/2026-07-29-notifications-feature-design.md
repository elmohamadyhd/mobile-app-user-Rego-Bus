# Notifications inbox + push token — design

**Date:** 2026-07-29  
**Status:** Approved for implementation

## Goal

Ship an authenticated in-app notification inbox (list, clear-all, swipe-delete)
and register the device push token with the backend when the user is signed in.
Wire the home hero bell to the inbox. Match Skyline Batch 6 screen **31 ·
Notifications**, adapted to the real Wadeny API.

## Current state

- No `lib/features/notifications/` slice.
- Home uses `SkylineTabHeroBellButton` with `onTap: null` and a always-on amber
  badge (`lib/shared/widgets/skyline_tab_hero.dart`, `home_screen.dart`).
- Register already sends `firebase_token` via
  `SecureStorage.readOrCreateDeviceToken()` (install UUID until real FCM).
- APIs in `docs/wadeny-apis.md` / Postman: list + delete collection; product
  confirmed delete-by-id at `DELETE /profile/notifications/:id` (not in the
  markdown quick-ref — treat as required).

## Backend APIs

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/profile/notifications` | Paginated list |
| `DELETE` | `/profile/notifications` | Clear all |
| `DELETE` | `/profile/notifications/:id` | Delete one |
| `PUT` | `/profile/firebase/token` | Register/update push token |

All require bearer auth. Locale via existing Dio `Accept-Language` interceptor.

### List response shape

```json
{
  "status": 200,
  "message": "Notification list",
  "errors": {},
  "data": [
    {
      "id": "f2ddd3f1-97f7-4797-a016-e5f31c29572c",
      "title": "تهانئ",
      "description": "تم توثيق حسابك بنجاح",
      "created_date": "2026-07-02 12:48:02",
      "formatted_date": "2026-07-02 12:48 pm",
      "data": {},
      "read_at": "2026-07-02T10:56:45.000000Z"
    }
  ],
  "pagination": {
    "total": 2,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

Unread = `read_at == null` (or missing).

### Clear-all / delete-one

Both return `{ status: 200, message: "…", errors: {}, data: {} }` on success.

### Update Firebase token

`PUT /profile/firebase/token` with form-data field `firebase_token` (same key as
register / delete-account). Postman request body is empty in the collection —
this field name is the documented assumption.

## Design vs API gaps

| V1 design element | API support | v1 decision |
|-------------------|-------------|-------------|
| “Mark all read” | No mark-read endpoint | **Clear all** label + confirm → `DELETE` collection |
| Per-type icons (booking / offer / system) | `data` empty in samples | Generic bell icon for every card |
| New / Earlier sections | Derived from `read_at` | **New** = unread; **Earlier** = read |
| Swipe delete | `DELETE …/:id` (product-confirmed) | Swipe end→start → delete; rollback on error |
| Tap → deep link | Not specified | **No-op** |
| Unread blue dot | `read_at` | Show when unread |
| Always-on home badge | — | Amber dot only when logged-in and ≥1 unread |

## Non-goals (v1)

- Notification tap navigation / deep links.
- Foreground push presentation UI / handling notification-open intents.
- “Mark all read” (no API).
- Settings toggles for notification preferences.
- Typed icons from `data` payload.
- Adding Firebase Console credentials / `google-services.json` /
  `GoogleService-Info.plist` into the repo (blocked on project ownership).

## Push token strategy

**Product intent:** sync a push token via `PUT /profile/firebase/token` whenever
the user has an authenticated session.

**v1 implementation (no Firebase project files in repo):**

1. Introduce `PushTokenProvider` in the notifications feature.
2. Default impl returns `SecureStorage.readOrCreateDeviceToken()` — same bridge
   register already uses.
3. `FcmRegistrar` (Riverpod): when session is authenticated and not guest,
   obtain token → `updateFirebaseToken`; listen for token refresh if/when the
   provider exposes a stream (device-token impl has no refresh stream).
4. Failures: log only; never block inbox or login.
5. **Follow-up (separate PR):** add `firebase_core` + `firebase_messaging`,
   platform config files, and swap the provider to real FCM tokens. Do **not**
   add those packages in this PR (Android/iOS build would break without config).

## Architecture

Standalone slice (mirrors addresses / wallet):

```
lib/features/notifications/
├── data/
│   ├── notifications_api.dart
│   ├── notifications_dto_mapper.dart
│   └── notifications_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── app_notification.dart       # Freezed
│   │   └── notifications_page.dart
│   └── repositories/
│       └── notifications_repository.dart
└── presentation/
    ├── notifications_routes.dart
    ├── notifications_screen.dart
    ├── providers/
    │   ├── notifications_providers.dart
    │   ├── push_token_provider.dart
    │   └── fcm_registrar.dart
    └── widgets/
        ├── notifications_app_bar.dart
        ├── notification_card.dart
        └── notifications_section_header.dart
```

Route: `/profile/notifications` federated into `app_router.dart`.

### Domain

```dart
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String title,
    required String description,
    required String createdDate,
    required String formattedDate,
    @Default({}) Map<String, dynamic> data,
    DateTime? readAt,
  }) = _AppNotification;
}

// Extension or private getter: isUnread => readAt == null
```

`NotificationsPage` mirrors `AddressPage` (`items`, `currentPage`, `lastPage`,
`total`, `hasNextPage`, `append`).

### Repository

```dart
abstract class NotificationsRepository {
  Future<NotificationsPage> list({int page = 1});
  Future<void> deleteAll();
  Future<void> delete(String id);
  Future<void> updateFirebaseToken(String token);
}
```

### Providers

- `notificationsProvider` — `AsyncNotifier<NotificationsPage>` with
  `refresh` / `loadMore` / `delete` / `clearAll`.
- `hasUnreadNotificationsProvider` — `Provider<bool>`: `false` for guests /
  unauthenticated; otherwise `true` if any item in the loaded page is unread
  (prefetch list when authenticated on home, or watch notifications provider
  only after first load — prefer: when not guest, `ref.watch(notificationsProvider)`
  and derive unread; accept that home may trigger a list fetch).
- `fcmRegistrarProvider` — side-effect provider watched from `App` or home:
  registers token on auth; no-op for guests.

### UI

- App bar: back · localized title · **Clear all** (primary; hidden when empty).
- Confirm dialog before clear-all.
- Body: New section then Earlier; cards with icon, title, description,
  `formattedDate`, unread dot.
- Swipe-to-delete; optimistic remove; snackbar on failure + refresh.
- Empty / loading / error+retry (addresses pattern).
- Responsive: `SafeArea`, scroll, `AppBreakpoints.maxContentWidth` when expanded.
- All strings in `app_en.arb` + `app_ar.arb`; Phosphor icons; design tokens.

### Home / guest

- Bell `onTap`: guest → `context.go(login, AuthGateArgs(returnTo: list))`;
  else `context.push(NotificationsRoutes.list)`.
- Badge: `showBadge: hasUnread` (extend `SkylineTabHeroBellButton`).

## Error handling

| Case | Behavior |
|------|----------|
| List fail | Error message + retry |
| Delete one fail | Rollback list; snackbar |
| Clear all fail | Keep list; snackbar |
| Token PUT fail | Log; silent |

## Testing

- Mapper: parse list, unread vs read, pagination.
- Notifier: load, loadMore, delete, clearAll.
- Widget smoke (locale `ar`): empty, list with Clear all, guest bell → login path
  (home test if existing harness allows).
- Registrar: with fake repo + fake token provider, calls `updateFirebaseToken`
  when authenticated.

## File touch list (expected)

| Action | Path |
|--------|------|
| Create | `lib/features/notifications/**` (as above) |
| Create | `test/features/notifications/**` |
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/features/home/presentation/home_screen.dart` |
| Modify | `lib/shared/widgets/skyline_tab_hero.dart` (`showBadge`) |
| Modify | `lib/l10n/app_en.arb`, `app_ar.arb` |
| Modify | `lib/app.dart` (watch FCM registrar) if needed |
| Docs | this spec + implementation plan |

## Approval record

- Scope: full inbox UX (C) + Clear all (A) + swipe delete-by-id + no tap nav (A)
  + token sync (B, via device-token bridge until Firebase config lands).
- Architecture: Approach 1 — standalone `notifications` feature.
