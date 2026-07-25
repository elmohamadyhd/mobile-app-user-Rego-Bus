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
