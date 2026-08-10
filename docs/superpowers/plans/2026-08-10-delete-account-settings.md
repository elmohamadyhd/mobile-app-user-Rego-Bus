# Delete Account (Settings) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let signed-in riders delete their account from Settings via `DELETE /profile`, after typing a localized confirm word, then clear the session token and land on login.

**Architecture:** Extend profile data layer (`ProfileApi` / `ProfileRepository`) with `deleteAccount()`. Settings shows a destructive row (signed-in only) that opens a typed-confirm dialog; on success call `sessionController.logout()` and `context.go(AppRoutes.login)`.

**Tech Stack:** Flutter, Riverpod, Dio, go_router, Skyline tokens, Phosphor Light, `flutter_test`, ARB/`flutter gen-l10n`.

**Spec:** [`docs/superpowers/specs/2026-08-10-delete-account-settings-design.md`](../specs/2026-08-10-delete-account-settings-design.md)

## Global Constraints

- Own under `profile` — no new settings feature slice
- API: `DELETE /profile`; success when envelope `status == 200`
- Confirm word from l10n: EN `DELETE`, AR `حذف` (exact trimmed match)
- Guests: hide Delete account
- Success: logout (clear token) then `go` login; failure: keep session + error
- Design tokens + Phosphor Light only; package imports `package:safaria/...`
- No soft-delete / password re-auth / grace period UI

## File map

| File | Role |
|------|------|
| `lib/features/profile/data/profile_api.dart` | `deleteAccount()` |
| `lib/features/profile/domain/repositories/profile_repository.dart` | Interface |
| `lib/features/profile/data/profile_repository_impl.dart` | Impl + envelope check |
| `lib/features/profile/presentation/settings_screen.dart` | Row + dialog + navigation |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Strings |
| `test/features/profile/data/profile_repository_impl_test.dart` | Repo tests |
| `test/features/profile/settings_screen_test.dart` | Widget tests |

---

### Task 1: Profile `deleteAccount` (TDD)

**Files:**
- Modify: `lib/features/profile/data/profile_api.dart`
- Modify: `lib/features/profile/domain/repositories/profile_repository.dart`
- Modify: `lib/features/profile/data/profile_repository_impl.dart`
- Modify: `test/features/profile/data/profile_repository_impl_test.dart`

**Interfaces:**
- Produces:
  - `Future<dynamic> ProfileApi.deleteAccount()`
  - `Future<void> ProfileRepository.deleteAccount()`

- [ ] **Step 1: Extend `_FakeProfileApi` and add failing tests**

In `test/features/profile/data/profile_repository_impl_test.dart`, update `_FakeProfileApi`:

```dart
class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({
    this.fetchBody,
    this.updateBody,
    this.onUpdate,
    this.verifyAltPhoneBody,
    this.deleteAccountBody,
    this.deleteAccountError,
  }) : super(Dio());

  final dynamic fetchBody;
  final dynamic updateBody;
  final dynamic verifyAltPhoneBody;
  final dynamic deleteAccountBody;
  final Object? deleteAccountError;
  final void Function(FormData body)? onUpdate;

  @override
  Future<dynamic> fetch() async => fetchBody;

  @override
  Future<dynamic> update(FormData body) async {
    onUpdate?.call(body);
    return updateBody;
  }

  @override
  Future<dynamic> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      verifyAltPhoneBody;

  @override
  Future<dynamic> deleteAccount() async {
    final err = deleteAccountError;
    if (err != null) throw err;
    return deleteAccountBody;
  }
}
```

Add inside the `ProfileRepositoryImpl` group:

```dart
    group('deleteAccount', () {
      test('completes when envelope status is 200', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountBody: {
              'status': 200,
              'message': 'Account deleted',
              'errors': <String, dynamic>{},
              'data': <String, dynamic>{},
            },
          ),
        );

        await repo.deleteAccount();
      });

      test('throws ApiException on an error envelope', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountBody: {
              'status': 400,
              'message': 'Cannot delete account',
              'errors': <String, dynamic>{},
              'data': <String, dynamic>{},
            },
          ),
        );

        await expectLater(
          repo.deleteAccount(),
          throwsA(isA<ApiException>()),
        );
      });

      test('throws ApiException on DioException', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountError: DioException(
              requestOptions: RequestOptions(path: '/profile'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        await expectLater(
          repo.deleteAccount(),
          throwsA(isA<ApiException>()),
        );
      });
    });
```

- [ ] **Step 2: Run tests — expect compile/fail**

```bash
flutter test test/features/profile/data/profile_repository_impl_test.dart
```

Expected: FAIL — `deleteAccount` missing on API/repository.

- [ ] **Step 3: Implement API + repository**

Add to `ProfileApi`:

```dart
  Future<dynamic> deleteAccount() async {
    final res = await _dio.delete('/profile');
    return res.data;
  }
```

Add to `ProfileRepository`:

```dart
  /// Permanently deletes the signed-in account via `DELETE /profile`.
  Future<void> deleteAccount();
```

Add to `ProfileRepositoryImpl`:

```dart
  @override
  Future<void> deleteAccount() => _guard(() async {
        final body = await _api.deleteAccount();
        final envelope = body as Map<String, dynamic>;
        final innerStatus = envelope['status'];
        if (innerStatus is num && innerStatus.toInt() != 200) {
          throw ApiException.fromEnvelope(envelope);
        }
      });
```

- [ ] **Step 4: Run tests — expect pass**

```bash
flutter test test/features/profile/data/profile_repository_impl_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/data/profile_api.dart \
  lib/features/profile/domain/repositories/profile_repository.dart \
  lib/features/profile/data/profile_repository_impl.dart \
  test/features/profile/data/profile_repository_impl_test.dart
git commit -m "feat(profile): add deleteAccount API and repository"
```

---

### Task 2: l10n + Settings Delete UI (TDD)

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`
- Modify: `lib/features/profile/presentation/settings_screen.dart`
- Modify: `test/features/profile/settings_screen_test.dart`

**Interfaces:**
- Consumes: `profileRepositoryProvider.deleteAccount()`, `sessionControllerProvider.logout()`, `guestModeProvider`, `AppRoutes.login`
- Produces: Delete row + typed confirm dialog on `SettingsScreen`

- [ ] **Step 1: Add ARB keys**

In `lib/l10n/app_en.arb` (near profile/settings strings):

```json
  "settingsDeleteAccount": "Delete account",
  "@settingsDeleteAccount": {
    "description": "Settings row that permanently deletes the rider account."
  },
  "settingsDeleteAccountTitle": "Delete account?",
  "@settingsDeleteAccountTitle": {
    "description": "Title of the delete-account confirmation dialog."
  },
  "settingsDeleteAccountMessage": "This permanently deletes your account and cannot be undone.",
  "@settingsDeleteAccountMessage": {
    "description": "Body of the delete-account confirmation dialog."
  },
  "settingsDeleteAccountTypePrompt": "Type {word} to confirm",
  "@settingsDeleteAccountTypePrompt": {
    "description": "Instruction to type the confirmation word before deleting.",
    "placeholders": {
      "word": { "type": "String" }
    }
  },
  "settingsDeleteAccountConfirmWord": "DELETE",
  "@settingsDeleteAccountConfirmWord": {
    "description": "Exact word the user must type to enable delete (English)."
  },
  "settingsDeleteAccountCancel": "Cancel",
  "@settingsDeleteAccountCancel": {
    "description": "Cancel button on the delete-account dialog."
  },
  "settingsDeleteAccountConfirm": "Delete",
  "@settingsDeleteAccountConfirm": {
    "description": "Confirm button on the delete-account dialog."
  },
  "settingsDeleteAccountFailed": "Couldn't delete account",
  "@settingsDeleteAccountFailed": {
    "description": "Snackbar when DELETE /profile fails."
  }
```

In `lib/l10n/app_ar.arb`:

```json
  "settingsDeleteAccount": "حذف الحساب",
  "settingsDeleteAccountTitle": "حذف الحساب؟",
  "settingsDeleteAccountMessage": "سيتم حذف حسابك نهائيًا ولا يمكن التراجع عن ذلك.",
  "settingsDeleteAccountTypePrompt": "اكتب {word} للتأكيد",
  "settingsDeleteAccountConfirmWord": "حذف",
  "settingsDeleteAccountCancel": "إلغاء",
  "settingsDeleteAccountConfirm": "حذف",
  "settingsDeleteAccountFailed": "تعذر حذف الحساب"
```

Run:

```bash
flutter gen-l10n
```

- [ ] **Step 2: Write failing Settings widget tests**

Extend `test/features/profile/settings_screen_test.dart`. Add imports and fakes as needed:

```dart
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';
```

Add fakes (mirror profile_screen_test session/guest fakes) plus:

```dart
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.onDelete, this.deleteError});

  final Future<void> Function()? onDelete;
  final Object? deleteError;
  var deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls += 1;
    final err = deleteError;
    if (err != null) throw err;
    await onDelete?.call();
  }

  @override
  Future<AuthUser> fetchProfile() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();
}
```

Update `pumpSettings` to accept optional session/guest/repo overrides:

```dart
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    AuthSession? session,
    bool isGuest = false,
    ProfileRepository? profileRepository,
    Widget? home,
    List<Override> extraOverrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        if (profileRepository != null)
          profileRepositoryProvider.overrideWithValue(profileRepository),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          locale: locale,
          home: home ?? const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }
```

Copy `_FakeSessionController` / `_FakeGuestController` from `profile_screen_test.dart` into this file (same shape).

Add tests:

```dart
  const signedIn = AuthSession(
    token: 'tok',
    user: AuthUser(name: 'Ahmed', mobile: '1012345678', phoneCode: '20'),
  );

  testWidgets('hides Delete account for guests', (tester) async {
    await pumpSettings(tester, isGuest: true, session: null);

    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('shows Delete account for signed-in users', (tester) async {
    await pumpSettings(tester, session: signedIn);

    expect(find.text('Delete account'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.trash), findsOneWidget);
  });

  testWidgets('Delete stays disabled until confirm word matches',
      (tester) async {
    await pumpSettings(tester, session: signedIn);

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final deleteAction = find.widgetWithText(TextButton, 'Delete');
    expect(
      tester.widget<TextButton>(deleteAction).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();

    expect(
      tester.widget<TextButton>(deleteAction).onPressed,
      isNotNull,
    );
  });

  testWidgets('successful delete logs out and goes to login', (tester) async {
    final repo = _FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(signedIn),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(false)),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/settings-test',
      routes: [
        GoRoute(
          path: '/settings-test',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Text('LOGIN'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.deleteCalls, 1);
    expect(container.read(sessionControllerProvider).value, isNull);
    expect(find.text('LOGIN'), findsOneWidget);
  });
```

Keep existing language tests working — they must pass session/guest overrides (default `session: null`, `isGuest: false` still hides Delete; that is fine).

- [ ] **Step 3: Run Settings tests — expect fail**

```bash
flutter test test/features/profile/settings_screen_test.dart
```

Expected: FAIL — Delete account UI missing / keys unused.

- [ ] **Step 4: Implement Settings UI**

Refactor `settings_screen.dart` to a `ConsumerStatefulWidget` **or** keep `ConsumerWidget` and use a small `StatefulWidget` dialog. Preferred: keep screen as `ConsumerWidget`; dialog is a private `StatefulWidget`.

Skeleton for the screen body card:

```dart
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    final session = ref.watch(sessionControllerProvider).value;
    final showDelete = !isGuest && session != null;

    // ...
    child: _SettingsMenuCard(
      children: [
        _SettingsLanguageTile(...),
        if (showDelete) ...[
          const Divider(
            color: AppColors.hairline,
            height: 1,
            indent: AppSpacing.lg + 40 + AppSpacing.md,
          ),
          _SettingsDeleteTile(
            label: l10n.settingsDeleteAccount,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ],
    ),
```

Update `_SettingsMenuCard` to take `List<Widget> children` (or a single `child` Column). Destructive tile mirrors profile logout colors with `PhosphorIconsLight.trash`.

Implement `_confirmDeleteAccount`:

```dart
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _DeleteAccountDialog(),
  );
  if (deleted != true || !context.mounted) return;

  await ref.read(sessionControllerProvider.notifier).logout();
  if (!context.mounted) return;
  context.go(AppRoutes.login);
}
```

`_DeleteAccountDialog` (stateful):

- Reads l10n; `word = l10n.settingsDeleteAccountConfirmWord`
- TextField `onChanged` → setState; `matches = controller.text.trim() == word`
- Confirm `TextButton`: `onPressed: matches && !_submitting ? _submit : null`
- `_submit`: set submitting; `await ref.read(profileRepositoryProvider).deleteAccount()`; on success `Navigator.pop(context, true)`; on `ApiException` snackbar with `e.message` or `l10n.settingsDeleteAccountFailed`, clear submitting
- Wrap Latin confirm field with `Directionality(textDirection: TextDirection.ltr, ...)` when `word` is ASCII-only; otherwise inherit

Import: `go_router`, `app_router`, auth providers, profile providers, `ApiException`.

- [ ] **Step 5: Run tests + analyze**

```bash
flutter gen-l10n
flutter test test/features/profile/settings_screen_test.dart \
  test/features/profile/data/profile_repository_impl_test.dart
dart format lib/features/profile lib/l10n/app_en.arb lib/l10n/app_ar.arb \
  test/features/profile
flutter analyze lib/features/profile test/features/profile
```

Expected: PASS / no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb \
  lib/features/profile/presentation/settings_screen.dart \
  test/features/profile/settings_screen_test.dart
git commit -m "feat(profile): delete account from Settings with typed confirm"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `DELETE /profile` + envelope 200 | 1 |
| Settings Delete row + destructive style | 2 |
| Guests hide Delete | 2 |
| Typed localized confirm word | 2 |
| Success → logout + login | 2 |
| Failure keeps session + error | 2 |
| ARB keys EN/AR | 2 |
| Tests repo + settings | 1, 2 |

## Out of scope

- Soft-delete, password re-auth, Help/theme settings
- Changing onboarding/login language entry points
