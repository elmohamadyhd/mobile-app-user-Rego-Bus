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
