import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in an external app (browser, Google Maps, etc.).
Future<bool> launchExternalUrl(Uri uri) async {
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
