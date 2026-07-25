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
