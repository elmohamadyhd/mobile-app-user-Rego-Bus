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
