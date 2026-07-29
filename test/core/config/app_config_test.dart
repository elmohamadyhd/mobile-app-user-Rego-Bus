import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/config/app_config.dart';

void main() {
  group('AppConfig.isGoogleSignInConfigured', () {
    test('is false when GOOGLE_WEB_CLIENT_ID is empty', () {
      dotenv.testLoad(fileInput: 'GOOGLE_WEB_CLIENT_ID=');

      expect(AppConfig.googleWebClientId, '');
      expect(AppConfig.isGoogleSignInConfigured, isFalse);
    });

    test('is true when GOOGLE_WEB_CLIENT_ID is set', () {
      dotenv.testLoad(
        fileInput: 'GOOGLE_WEB_CLIENT_ID=abc123.apps.googleusercontent.com',
      );

      expect(
        AppConfig.googleWebClientId,
        'abc123.apps.googleusercontent.com',
      );
      expect(AppConfig.isGoogleSignInConfigured, isTrue);
    });
  });
}
