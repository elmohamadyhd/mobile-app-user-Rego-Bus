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
