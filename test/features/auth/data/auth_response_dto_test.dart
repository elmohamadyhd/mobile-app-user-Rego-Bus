import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/auth/data/models/auth_response_dto.dart';

void main() {
  group('AuthResponseDto', () {
    test('maps login response data to AuthSession', () {
      const payload = {
        'id': 75,
        'name': 'abdallah',
        'email': 'elmohamady82@gmail.com',
        'mobile': '1554052685',
        'phonecode': '20',
        'status': 'Active',
        'avatar': '',
        'api_token': '1|abc123',
        'is_profile_completed': true,
      };

      final session = AuthResponseDto.fromJson(payload).toEntity();

      expect(session.token, '1|abc123');
      expect(session.user?.id, 75);
      expect(session.user?.name, 'abdallah');
      expect(session.user?.email, 'elmohamady82@gmail.com');
      expect(session.user?.mobile, '1554052685');
      expect(session.user?.phoneCode, '20');
      expect(session.user?.status, 'Active');
      expect(session.user?.avatarUrl, '');
      expect(session.user?.isProfileCompleted, true);
    });

    test('coerces mobile and phonecode when sent as integers', () {
      const payload = {
        'id': 75,
        'name': 'abdallah',
        'mobile': 1554052685,
        'phonecode': 20,
        'api_token': '1|abc123',
      };

      final session = AuthResponseDto.fromJson(payload).toEntity();

      expect(session.user?.mobile, '1554052685');
      expect(session.user?.phoneCode, '20');
    });

    test('parses session when id is absent but api_token is present', () {
      const payload = {
        'api_token': '1|abc123',
      };

      final session = AuthResponseDto.fromJson(payload).toEntity();

      expect(session.token, '1|abc123');
      expect(session.user?.id, isNull);
      expect(session.user?.name, isNull);
    });
  });
}
