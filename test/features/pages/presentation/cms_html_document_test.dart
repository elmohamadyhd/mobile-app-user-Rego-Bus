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
