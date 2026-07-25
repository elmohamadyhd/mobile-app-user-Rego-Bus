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
