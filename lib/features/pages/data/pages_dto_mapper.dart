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
