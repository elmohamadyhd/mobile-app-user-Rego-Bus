import 'package:safaria/features/pages/domain/entities/cms_page.dart';

abstract interface class PagesRepository {
  Future<List<CmsPageSummary>> listPages();

  Future<CmsPage> getPage(String slug);
}
