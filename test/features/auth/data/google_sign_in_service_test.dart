import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:safaria/features/auth/data/google_sign_in_service.dart';

void main() {
  group('GoogleSignInService.mapCancellation', () {
    test('returns null for a canceled exception', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(GoogleSignInService.mapCancellation(exception), isNull);
    });

    test('rethrows a GoogleSignInFailure for any other exception code', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'missing client id',
      );

      expect(
        () => GoogleSignInService.mapCancellation(exception),
        throwsA(
          isA<GoogleSignInFailure>().having(
            (e) => e.message,
            'message',
            'missing client id',
          ),
        ),
      );
    });
  });
}
