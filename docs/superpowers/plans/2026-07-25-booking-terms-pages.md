# Booking Terms Checkbox + CMS Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate Confirm & Pay behind a Terms and Conditions checkbox on booking confirmation, with a reusable CMS pages feature that loads HTML from `GET /pages/{slug}`.

**Architecture:** New `lib/features/pages/` slice (API → repository → `PageDetailScreen` + `/pages/:slug`). Shared `BookingTermsCheckbox` + `GatedPrimaryButton` live in `lib/shared/widgets/`. Path/slug constants live in `lib/shared/pages/` so shared widgets never import a feature. Bus `PassengerConfirmScreen` wires the gate first.

**Tech Stack:** Flutter, Riverpod (no codegen for providers), go_router, Freezed entities, Dio, existing `webview_flutter`.

**Spec:** `docs/superpowers/specs/2026-07-25-booking-terms-pages-design.md` — read it first.

**Verification:** Every task ends with `flutter analyze` and/or targeted `flutter test`. Run `dart run build_runner build --delete-conflicting-outputs` after Freezed edits. Run `flutter gen-l10n` after ARB edits.

## Global Constraints

- No new pub packages — use existing `webview_flutter`.
- No hardcoded user-facing strings — ARB keys in both `app_en.arb` and `app_ar.arb`.
- `shared/` must not import `features/`; path/slug constants go in `shared/pages/`.
- Acceptance is local UI state only — not sent on `create-ticket`.
- Booking gate is checkbox-only (page load failure does not block booking).
- Icons via `AppIcons`; colors/spacing via `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`.
- Package imports only (`package:safaria/...`).

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/shared/pages/cms_page_paths.dart` | Slug + route path constants (shared + features) |
| `lib/features/pages/domain/entities/cms_page.dart` | Freezed `CmsPage`, `CmsPageSummary` |
| `lib/features/pages/domain/repositories/pages_repository.dart` | Abstract repo |
| `lib/features/pages/data/pages_api.dart` | Dio `GET /pages`, `GET /pages/{slug}` |
| `lib/features/pages/data/pages_dto_mapper.dart` | Envelope → entities |
| `lib/features/pages/data/pages_repository_impl.dart` | Repo impl + Dio→ApiException |
| `lib/features/pages/presentation/providers/pages_providers.dart` | Repo + `pageDetailProvider` |
| `lib/features/pages/presentation/pages_routes.dart` | `/pages/:slug` GoRoute |
| `lib/features/pages/presentation/cms_html_document.dart` | Wrap API HTML for WebView |
| `lib/features/pages/presentation/page_detail_screen.dart` | Full-screen CMS page |
| `lib/shared/widgets/booking_terms_checkbox.dart` | Agree row + link |
| `lib/shared/widgets/gated_primary_button.dart` | Disabled look + tap-through snackbar |
| `lib/features/bus/presentation/passenger_confirm_screen.dart` | Wire checkbox + gate |
| `lib/core/router/app_router.dart` | Spread `pagesRoutes()` |
| `lib/l10n/app_en.arb` / `app_ar.arb` | New strings |
| `test/features/pages/data/pages_repository_impl_test.dart` | Mapper/repo tests |
| `test/features/pages/data/pages_fixtures.dart` | JSON fixtures |
| `test/features/pages/presentation/cms_html_document_test.dart` | HTML wrapper unit test |
| `test/shared/widgets/gated_primary_button_test.dart` | Gate UX tests |
| `test/shared/widgets/booking_terms_checkbox_test.dart` | Checkbox/link tests |

---

### Task 1: Shared path constants + domain layer

**Files:**
- Create: `lib/shared/pages/cms_page_paths.dart`
- Create: `lib/features/pages/domain/entities/cms_page.dart`
- Create: `lib/features/pages/domain/repositories/pages_repository.dart`

**Interfaces:**
- Produces: `CmsPagePaths`, `CmsPage`, `CmsPageSummary`, `PagesRepository`

- [ ] **Step 1: Create path constants**

```dart
// lib/shared/pages/cms_page_paths.dart
/// CMS page slugs and go_router paths. Lives in shared so booking widgets
/// can navigate without importing `features/pages`.
abstract final class CmsPagePaths {
  static const termsSlug = 'terms-and-conditions';
  static const privacySlug = 'privacy-and-policy';

  static const terms = '/pages/$termsSlug';
  static const privacy = '/pages/$privacySlug';

  static String detail(String slug) => '/pages/$slug';
}
```

- [ ] **Step 2: Create Freezed entities**

```dart
// lib/features/pages/domain/entities/cms_page.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cms_page.freezed.dart';

@freezed
abstract class CmsPageSummary with _$CmsPageSummary {
  const factory CmsPageSummary({
    required int id,
    required String title,
    required String slug,
    required int status,
  }) = _CmsPageSummary;
}

@freezed
abstract class CmsPage with _$CmsPage {
  const factory CmsPage({
    required int id,
    required String slug,
    required String title,
    required String content,
    required int status,
  }) = _CmsPage;
}
```

- [ ] **Step 3: Create repository interface**

```dart
// lib/features/pages/domain/repositories/pages_repository.dart
import 'package:safaria/features/pages/domain/entities/cms_page.dart';

abstract interface class PagesRepository {
  Future<List<CmsPageSummary>> listPages();

  Future<CmsPage> getPage(String slug);
}
```

- [ ] **Step 4: Run Freezed codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: generates `cms_page.freezed.dart` with no errors.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/shared/pages lib/features/pages/domain`

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/shared/pages/cms_page_paths.dart lib/features/pages/domain
git commit -m "feat(pages): add CMS path constants and domain types"
```

---

### Task 2: Pages data layer (TDD)

**Files:**
- Create: `lib/features/pages/data/pages_api.dart`
- Create: `lib/features/pages/data/pages_dto_mapper.dart`
- Create: `lib/features/pages/data/pages_repository_impl.dart`
- Create: `test/features/pages/data/pages_fixtures.dart`
- Create: `test/features/pages/data/pages_repository_impl_test.dart`

**Interfaces:**
- Consumes: `PagesRepository`, `CmsPage`, `CmsPageSummary`
- Produces: `PagesApi`, `PagesDtoMapper`, `PagesRepositoryImpl`

- [ ] **Step 1: Write fixtures**

```dart
// test/features/pages/data/pages_fixtures.dart
const listEnvelope = {
  'status': 200,
  'message': 'Pages',
  'errors': {},
  'data': [
    {
      'id': 2,
      'title': 'Privacy And Policy',
      'slug': 'privacy-and-policy',
      'status': 1,
    },
    {
      'id': 1,
      'title': 'Terms and Conditions',
      'slug': 'terms-and-conditions',
      'status': 1,
    },
  ],
};

const detailEnvelope = {
  'status': 200,
  'message': 'Page details',
  'errors': {},
  'data': {
    'id': 1,
    'slug': 'terms-and-conditions',
    'title': 'Terms and Conditions',
    'content': '<p>Terms body</p>',
    'status': 1,
  },
};

const inactiveDetailEnvelope = {
  'status': 200,
  'message': 'Page details',
  'errors': {},
  'data': {
    'id': 1,
    'slug': 'terms-and-conditions',
    'title': 'Terms and Conditions',
    'content': '<p>Terms body</p>',
    'status': 0,
  },
};
```

- [ ] **Step 2: Write failing repository tests**

```dart
// test/features/pages/data/pages_repository_impl_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/pages/data/pages_api.dart';
import 'package:safaria/features/pages/data/pages_repository_impl.dart';

import 'pages_fixtures.dart';

class _FakePagesApi extends PagesApi {
  _FakePagesApi({this.listBody, this.detailBody}) : super(Dio());

  final dynamic listBody;
  final dynamic detailBody;

  @override
  Future<dynamic> list() async => listBody;

  @override
  Future<dynamic> show(String slug) async => detailBody;
}

void main() {
  group('PagesRepositoryImpl', () {
    test('listPages() returns two summaries including terms slug', () async {
      final repo = PagesRepositoryImpl(
        _FakePagesApi(listBody: listEnvelope),
      );

      final pages = await repo.listPages();

      expect(pages, hasLength(2));
      expect(pages.last.slug, 'terms-and-conditions');
      expect(pages.last.title, 'Terms and Conditions');
      expect(pages.last.id, 1);
    });

    test('getPage() returns title and HTML content', () async {
      final repo = PagesRepositoryImpl(
        _FakePagesApi(detailBody: detailEnvelope),
      );

      final page = await repo.getPage('terms-and-conditions');

      expect(page.id, 1);
      expect(page.slug, 'terms-and-conditions');
      expect(page.title, 'Terms and Conditions');
      expect(page.content, '<p>Terms body</p>');
      expect(page.status, 1);
    });

    test('getPage() throws FormatException when status is not 1', () async {
      final repo = PagesRepositoryImpl(
        _FakePagesApi(detailBody: inactiveDetailEnvelope),
      );

      expect(
        () => repo.getPage('terms-and-conditions'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**

Run: `flutter test test/features/pages/data/pages_repository_impl_test.dart`

Expected: FAIL (missing `PagesApi` / `PagesRepositoryImpl`).

- [ ] **Step 4: Implement API**

```dart
// lib/features/pages/data/pages_api.dart
import 'package:dio/dio.dart';

class PagesApi {
  PagesApi(this._dio);

  final Dio _dio;

  Future<dynamic> list() async {
    final res = await _dio.get('/pages');
    return res.data;
  }

  Future<dynamic> show(String slug) async {
    final res = await _dio.get('/pages/$slug');
    return res.data;
  }
}
```

- [ ] **Step 5: Implement mapper**

```dart
// lib/features/pages/data/pages_dto_mapper.dart
import 'package:safaria/features/pages/domain/entities/cms_page.dart';

abstract final class PagesDtoMapper {
  static List<CmsPageSummary> listFromEnvelope(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data =
        (map['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return data.map(_summaryFromMap).toList(growable: false);
  }

  static CmsPage pageFromEnvelope(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected data object in page envelope');
    }
    final page = _pageFromMap(data);
    if (page.status != 1) {
      throw FormatException('Page inactive: ${page.slug}');
    }
    return page;
  }

  static CmsPageSummary _summaryFromMap(Map<String, dynamic> json) =>
      CmsPageSummary(
        id: _int(json['id']),
        title: json['title']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        status: _int(json['status']),
      );

  static CmsPage _pageFromMap(Map<String, dynamic> json) => CmsPage(
        id: _int(json['id']),
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        status: _int(json['status']),
      );

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}
```

- [ ] **Step 6: Implement repository**

```dart
// lib/features/pages/data/pages_repository_impl.dart
import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/pages/data/pages_api.dart';
import 'package:safaria/features/pages/data/pages_dto_mapper.dart';
import 'package:safaria/features/pages/domain/entities/cms_page.dart';
import 'package:safaria/features/pages/domain/repositories/pages_repository.dart';

class PagesRepositoryImpl implements PagesRepository {
  PagesRepositoryImpl(this._api);

  final PagesApi _api;

  @override
  Future<List<CmsPageSummary>> listPages() => _guard(
        () async => PagesDtoMapper.listFromEnvelope(await _api.list()),
      );

  @override
  Future<CmsPage> getPage(String slug) => _guard(
        () async => PagesDtoMapper.pageFromEnvelope(await _api.show(slug)),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
```

- [ ] **Step 7: Run tests — expect PASS**

Run: `flutter test test/features/pages/data/pages_repository_impl_test.dart`

Expected: All 3 tests PASS.

- [ ] **Step 8: Analyze + commit**

Run: `flutter analyze lib/features/pages/data test/features/pages/data`

```bash
git add lib/features/pages/data test/features/pages/data
git commit -m "feat(pages): add pages API, mapper, and repository"
```

---

### Task 3: Providers + routes

**Files:**
- Create: `lib/features/pages/presentation/providers/pages_providers.dart`
- Create: `lib/features/pages/presentation/pages_routes.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `PagesApi`, `PagesRepositoryImpl`, `CmsPagePaths`
- Produces: `pagesRepositoryProvider`, `pageDetailProvider(slug)`, `pagesRoutes()`

- [ ] **Step 1: Create providers**

```dart
// lib/features/pages/presentation/providers/pages_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/pages/data/pages_api.dart';
import 'package:safaria/features/pages/data/pages_repository_impl.dart';
import 'package:safaria/features/pages/domain/entities/cms_page.dart';
import 'package:safaria/features/pages/domain/repositories/pages_repository.dart';

final pagesApiProvider =
    Provider<PagesApi>((ref) => PagesApi(ref.watch(dioProvider)));

final pagesRepositoryProvider = Provider<PagesRepository>(
  (ref) => PagesRepositoryImpl(ref.watch(pagesApiProvider)),
);

/// Loads a single CMS page by slug. AutoDispose so leaving the screen
/// drops the cached HTML.
final pageDetailProvider =
    FutureProvider.autoDispose.family<CmsPage, String>((ref, slug) {
  return ref.watch(pagesRepositoryProvider).getPage(slug);
});
```

- [ ] **Step 2: Create routes (screen stub first so analyze passes)**

Create a minimal stub screen that Task 4 replaces:

```dart
// lib/features/pages/presentation/page_detail_screen.dart
import 'package:flutter/material.dart';

/// Full-screen CMS page. Implemented in Task 4.
class PageDetailScreen extends StatelessWidget {
  const PageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(slug)),
      body: const SizedBox.shrink(),
    );
  }
}
```

```dart
// lib/features/pages/presentation/pages_routes.dart
import 'package:go_router/go_router.dart';

import 'package:safaria/features/pages/presentation/page_detail_screen.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';

abstract final class PagesRoutes {
  /// Path pattern for go_router registration.
  static const detailPattern = '/pages/:slug';

  static String detail(String slug) => CmsPagePaths.detail(slug);
}

List<RouteBase> pagesRoutes() => [
      GoRoute(
        path: PagesRoutes.detailPattern,
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return PageDetailScreen(slug: slug);
        },
      ),
    ];
```

- [ ] **Step 3: Federate into app router**

In `lib/core/router/app_router.dart`:

1. Add import:
```dart
import 'package:safaria/features/pages/presentation/pages_routes.dart';
```

2. In the `routes:` list (alongside `...busRoutes()`, etc.), add:
```dart
      ...pagesRoutes(),
```

Place it near other feature spreads (e.g. after `...addressesRoutes()`).

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/features/pages/presentation lib/core/router/app_router.dart`

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/pages/presentation lib/core/router/app_router.dart
git commit -m "feat(pages): wire pageDetailProvider and /pages/:slug route"
```

---

### Task 4: Page detail screen + HTML wrapper + l10n

**Files:**
- Create: `lib/features/pages/presentation/cms_html_document.dart`
- Create: `test/features/pages/presentation/cms_html_document_test.dart`
- Modify: `lib/features/pages/presentation/page_detail_screen.dart` (replace stub)
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Consumes: `pageDetailProvider`, `CmsPagePaths`
- Produces: `wrapCmsHtml(...)`, full `PageDetailScreen`

- [ ] **Step 1: Add ARB keys (EN)**

In `lib/l10n/app_en.arb`, add (near other shared/content keys, or after confirm keys):

```json
  "cmsPageTermsTitle": "Terms and Conditions",
  "@cmsPageTermsTitle": {
    "description": "Fallback app-bar title while terms page is loading."
  },
  "cmsPagePrivacyTitle": "Privacy Policy",
  "@cmsPagePrivacyTitle": {
    "description": "Fallback app-bar title while privacy page is loading."
  },
  "cmsPageGenericTitle": "Page",
  "@cmsPageGenericTitle": {
    "description": "Fallback app-bar title for unknown CMS slugs."
  },
  "cmsPageLoadError": "Couldn't load this page. Please try again.",
  "@cmsPageLoadError": {
    "description": "Error body when GET /pages/{slug} fails."
  },
  "cmsPageRetry": "Retry",
  "@cmsPageRetry": {
    "description": "Retry button on CMS page error state."
  },
```

- [ ] **Step 2: Add ARB keys (AR)**

In `lib/l10n/app_ar.arb`:

```json
  "cmsPageTermsTitle": "الشروط والأحكام",
  "cmsPagePrivacyTitle": "سياسة الخصوصية",
  "cmsPageGenericTitle": "صفحة",
  "cmsPageLoadError": "تعذر تحميل هذه الصفحة. حاول مرة أخرى.",
  "cmsPageRetry": "إعادة المحاولة",
```

- [ ] **Step 3: Generate l10n**

Run: `flutter gen-l10n`

Expected: new getters on `AppLocalizations`.

- [ ] **Step 4: Write failing HTML wrapper test**

```dart
// test/features/pages/presentation/cms_html_document_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/pages/presentation/cms_html_document.dart';

void main() {
  test('wrapCmsHtml embeds content and sets rtl for ar', () {
    final html = wrapCmsHtml(
      content: '<p>مرحبا</p>',
      lang: 'ar',
      rtl: true,
    );

    expect(html, contains('lang="ar"'));
    expect(html, contains('dir="rtl"'));
    expect(html, contains('<p>مرحبا</p>'));
    expect(html, contains('<meta charset="utf-8">'));
  });

  test('wrapCmsHtml sets ltr for en', () {
    final html = wrapCmsHtml(
      content: '<p>Hello</p>',
      lang: 'en',
      rtl: false,
    );

    expect(html, contains('lang="en"'));
    expect(html, contains('dir="ltr"'));
  });
}
```

- [ ] **Step 5: Run test — expect FAIL**

Run: `flutter test test/features/pages/presentation/cms_html_document_test.dart`

Expected: FAIL (missing `wrapCmsHtml`).

- [ ] **Step 6: Implement HTML wrapper**

```dart
// lib/features/pages/presentation/cms_html_document.dart
/// Builds a minimal HTML document for [WebViewController.loadHtmlString].
String wrapCmsHtml({
  required String content,
  required String lang,
  required bool rtl,
}) {
  final dir = rtl ? 'rtl' : 'ltr';
  return '''
<!DOCTYPE html>
<html lang="$lang" dir="$dir">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    margin: 16px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 16px;
    line-height: 1.6;
    color: #1a1a1a;
  }
  img { max-width: 100%; height: auto; }
</style>
</head>
<body>
$content
</body>
</html>
''';
}
```

- [ ] **Step 7: Run HTML tests — expect PASS**

Run: `flutter test test/features/pages/presentation/cms_html_document_test.dart`

Expected: PASS.

- [ ] **Step 8: Implement `PageDetailScreen`**

Replace the stub with:

```dart
// lib/features/pages/presentation/page_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/pages/presentation/cms_html_document.dart';
import 'package:safaria/features/pages/presentation/providers/pages_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class PageDetailScreen extends ConsumerStatefulWidget {
  const PageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends ConsumerState<PageDetailScreen> {
  WebViewController? _controller;
  String? _loadedContent;

  String _fallbackTitle(AppLocalizations l10n) {
    if (widget.slug == CmsPagePaths.termsSlug) {
      return l10n.cmsPageTermsTitle;
    }
    if (widget.slug == CmsPagePaths.privacySlug) {
      return l10n.cmsPagePrivacyTitle;
    }
    return l10n.cmsPageGenericTitle;
  }

  void _ensureHtmlLoaded(String content) {
    if (_loadedContent == content && _controller != null) return;
    final locale = Localizations.localeOf(context);
    final html = wrapCmsHtml(
      content: content,
      lang: locale.languageCode,
      rtl: Directionality.of(context) == TextDirection.rtl,
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(AppColors.bgElevated)
      ..loadHtmlString(html);
    setState(() {
      _controller = controller;
      _loadedContent = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pageDetailProvider(widget.slug));

    final title = async.maybeWhen(
      data: (page) => page.title,
      orElse: () => _fallbackTitle(l10n),
    );

    return Scaffold(
      backgroundColor: AppColors.bgElevated,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        foregroundColor: AppColors.textPrimary,
        title: Text(title, style: AppTypography.title),
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.cmsPageLoadError,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.cmsPageRetry,
                onPressed: () {
                  setState(() {
                    _controller = null;
                    _loadedContent = null;
                  });
                  ref.invalidate(pageDetailProvider(widget.slug));
                },
              ),
            ],
          ),
        ),
        data: (page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureHtmlLoaded(page.content);
          });
          final controller = _controller;
          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return WebViewWidget(controller: controller);
        },
      ),
    );
  }
}
```

- [ ] **Step 9: Analyze + test**

Run:
```bash
flutter analyze lib/features/pages/presentation
flutter test test/features/pages/presentation/cms_html_document_test.dart
```

Expected: no issues; HTML tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/pages/presentation lib/l10n/app_en.arb lib/l10n/app_ar.arb test/features/pages/presentation
git commit -m "feat(pages): add PageDetailScreen with WebView HTML content"
```

---

### Task 5: Shared terms checkbox + gated button (TDD)

**Files:**
- Create: `lib/shared/widgets/booking_terms_checkbox.dart`
- Create: `lib/shared/widgets/gated_primary_button.dart`
- Create: `test/shared/widgets/gated_primary_button_test.dart`
- Create: `test/shared/widgets/booking_terms_checkbox_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Consumes: `CmsPagePaths`, `PrimaryButton`, `AppLocalizations`
- Produces: `BookingTermsCheckbox`, `GatedPrimaryButton`

- [ ] **Step 1: Add booking-terms ARB keys (EN)**

```json
  "confirmTermsAgreePrefix": "I agree to the ",
  "@confirmTermsAgreePrefix": {
    "description": "Text before the tappable Terms link on booking confirm."
  },
  "confirmTermsLink": "Terms and Conditions",
  "@confirmTermsLink": {
    "description": "Tappable Terms and Conditions label on booking confirm."
  },
  "confirmTermsRequired": "Please accept the Terms and Conditions to continue.",
  "@confirmTermsRequired": {
    "description": "Snackbar when Confirm is tapped while terms are unchecked."
  },
```

- [ ] **Step 2: Add ARB keys (AR)**

```json
  "confirmTermsAgreePrefix": "أوافق على ",
  "confirmTermsLink": "الشروط والأحكام",
  "confirmTermsRequired": "يرجى الموافقة على الشروط والأحكام للمتابعة.",
```

- [ ] **Step 3: Run `flutter gen-l10n`**

- [ ] **Step 4: Write failing gated-button tests**

```dart
// test/shared/widgets/gated_primary_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/shared/widgets/gated_primary_button.dart';

void main() {
  testWidgets('calls onPressed when not gated', (tester) async {
    var pressed = false;
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: false,
            onPressed: () => pressed = true,
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(pressed, isTrue);
    expect(blocked, isFalse);
  });

  testWidgets('calls onGateBlocked when gated', (tester) async {
    var pressed = false;
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: true,
            onPressed: () => pressed = true,
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(pressed, isFalse);
    expect(blocked, isTrue);
  });

  testWidgets('does not call onGateBlocked while loading', (tester) async {
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: true,
            loading: true,
            onPressed: () {},
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GatedPrimaryButton));
    await tester.pump();

    expect(blocked, isFalse);
  });
}
```

- [ ] **Step 5: Run — expect FAIL**

Run: `flutter test test/shared/widgets/gated_primary_button_test.dart`

Expected: FAIL (missing widget).

- [ ] **Step 6: Implement `GatedPrimaryButton`**

```dart
// lib/shared/widgets/gated_primary_button.dart
import 'package:flutter/material.dart';

import 'package:safaria/shared/widgets/primary_button.dart';

/// [PrimaryButton] that looks disabled when [gated], but still reports
/// [onGateBlocked] so the caller can show a snackbar.
class GatedPrimaryButton extends StatelessWidget {
  const GatedPrimaryButton({
    super.key,
    required this.label,
    required this.gated,
    required this.onPressed,
    required this.onGateBlocked,
    this.loading = false,
  });

  final String label;
  final bool gated;
  final bool loading;
  final VoidCallback onPressed;
  final VoidCallback onGateBlocked;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return PrimaryButton(label: label, loading: true, onPressed: null);
    }
    if (!gated) {
      return PrimaryButton(label: label, onPressed: onPressed);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onGateBlocked,
      child: PrimaryButton(label: label, onPressed: null),
    );
  }
}
```

- [ ] **Step 7: Run gated tests — expect PASS**

Run: `flutter test test/shared/widgets/gated_primary_button_test.dart`

Expected: All PASS.

- [ ] **Step 8: Write checkbox widget tests**

```dart
// test/shared/widgets/booking_terms_checkbox_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('toggles value via onChanged', (tester) async {
    var value = false;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return BookingTermsCheckbox(
              value: value,
              onChanged: (v) => setState(() => value = v),
              onOpenTerms: () {},
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(value, isTrue);
  });

  testWidgets('tapping terms link calls onOpenTerms', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      _wrap(
        BookingTermsCheckbox(
          value: false,
          onChanged: (_) {},
          onOpenTerms: () => opened = true,
        ),
      ),
    );

    await tester.tap(find.text('Terms and Conditions'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
```

- [ ] **Step 9: Run — expect FAIL, then implement checkbox**

```dart
// lib/shared/widgets/booking_terms_checkbox.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

class BookingTermsCheckbox extends StatelessWidget {
  const BookingTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.confirmTermsAgreePrefix,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: onOpenTerms,
                child: Text(
                  l10n.confirmTermsLink,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 10: Run all shared widget tests**

Run:
```bash
flutter test test/shared/widgets/gated_primary_button_test.dart test/shared/widgets/booking_terms_checkbox_test.dart
flutter analyze lib/shared/widgets/booking_terms_checkbox.dart lib/shared/widgets/gated_primary_button.dart
```

Expected: PASS; no issues.

- [ ] **Step 11: Commit**

```bash
git add lib/shared/widgets/booking_terms_checkbox.dart lib/shared/widgets/gated_primary_button.dart test/shared/widgets lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(shared): add booking terms checkbox and gated primary button"
```

---

### Task 6: Wire bus PassengerConfirmScreen

**Files:**
- Modify: `lib/features/bus/presentation/passenger_confirm_screen.dart`

**Interfaces:**
- Consumes: `BookingTermsCheckbox`, `GatedPrimaryButton`, `CmsPagePaths`

- [ ] **Step 1: Convert screen to `ConsumerStatefulWidget`**

Change:

```dart
class PassengerConfirmScreen extends ConsumerWidget {
  const PassengerConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

To:

```dart
class PassengerConfirmScreen extends ConsumerStatefulWidget {
  const PassengerConfirmScreen({super.key});

  @override
  ConsumerState<PassengerConfirmScreen> createState() =>
      _PassengerConfirmScreenState();
}

class _PassengerConfirmScreenState
    extends ConsumerState<PassengerConfirmScreen> {
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
```

Move the existing `build` body into `_PassengerConfirmScreenState.build`. Replace every previous `ref` usage as-is (still available via `ConsumerState`).

- [ ] **Step 2: Add imports**

```dart
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/gated_primary_button.dart';
```

Remove unused `primary_button.dart` import if `PrimaryButton` is no longer referenced directly.

- [ ] **Step 3: Replace bottom `PrimaryButton` with `GatedPrimaryButton`**

Replace the `bottomNavigationBar` button child:

```dart
          child: GatedPrimaryButton(
            label: l10n.confirmBook,
            loading: isLoading,
            gated: !_termsAccepted,
            onPressed: () =>
                ref.read(busBookingProvider.notifier).confirmBooking(),
            onGateBlocked: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.confirmTermsRequired)),
              );
            },
          ),
```

- [ ] **Step 4: Insert checkbox above the bottom bar (in scroll content)**

After `_PriceBreakdown(...)` and its `SizedBox`, add:

```dart
                  const SizedBox(height: AppSpacing.md),
                  BookingTermsCheckbox(
                    value: _termsAccepted,
                    onChanged: (v) => setState(() => _termsAccepted = v),
                    onOpenTerms: () => context.push(CmsPagePaths.terms),
                  ),
```

(Ensure `go_router` `context.push` import already exists.)

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/bus/presentation/passenger_confirm_screen.dart`

Expected: `No issues found!`

- [ ] **Step 6: Manual smoke (optional but recommended)**

Run the app, open a bus booking through to confirm:

1. Confirm button looks disabled; tap → snackbar.
2. Tap terms link → `/pages/terms-and-conditions` loads HTML (or error+retry if API down).
3. Check box → Confirm enabled → booking proceeds as before.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/passenger_confirm_screen.dart
git commit -m "feat(bus): require terms acceptance before confirm and pay"
```

---

### Task 7: Final verification

- [ ] **Step 1: Regenerate l10n if needed**

Run: `flutter gen-l10n`

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 3: Run all new tests**

Run:
```bash
flutter test test/features/pages test/shared/widgets/gated_primary_button_test.dart test/shared/widgets/booking_terms_checkbox_test.dart
```

Expected: All PASS.

- [ ] **Step 4: Commit any leftover formatting / l10n generated notes**

Only if there are remaining tracked changes (ARB already committed in earlier tasks). Do not commit gitignored generated files.

```bash
git status
```

If clean, skip commit. If ARB/format leftovers remain:

```bash
git add -u
git commit -m "chore(pages): final cleanup for booking terms gate"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `features/pages/` API + entities + repo | 1–2 |
| `GET /pages` + `GET /pages/{slug}` | 2 |
| Inactive `status != 1` → error | 2 |
| `pageDetailProvider` + `/pages/:slug` | 3 |
| Full-screen HTML WebView | 4 |
| Shared checkbox + gated button | 5 |
| Bus confirm wire-up | 6 |
| Settings wiring | Out of scope (paths ready via `CmsPagePaths.privacy`) |
| Flight/car confirm | Out of scope (shared widgets ready) |
| No booking API change | 6 (local state only) |

## Self-review notes (resolved while writing)

- Shared widgets cannot import `features/pages` → `CmsPagePaths` in `shared/pages/`.
- Checkbox uses Wrap + GestureDetector (no `TapGestureRecognizer` leak).
- Gate uses `GestureDetector` over a disabled `PrimaryButton`.
- Page detail loads HTML once per content string via `_ensureHtmlLoaded`; retry clears controller then invalidates provider.
- Tests cover HTML wrapper + repo + shared widgets; no WebView integration test in v1.
