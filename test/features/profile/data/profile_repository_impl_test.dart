import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/profile/data/profile_api.dart';
import 'package:safaria/features/profile/data/profile_repository_impl.dart';

import 'profile_fixtures.dart';

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({this.fetchBody, this.updateBody}) : super(Dio());

  final dynamic fetchBody;
  final dynamic updateBody;

  @override
  Future<dynamic> fetch() async => fetchBody;

  @override
  Future<dynamic> update(FormData body) async => updateBody;
}

void main() {
  group('ProfileRepositoryImpl', () {
    test('fetchProfile() returns user with id 69', () async {
      final repo = ProfileRepositoryImpl(
        _FakeProfileApi(fetchBody: profileEnvelope),
      );

      final user = await repo.fetchProfile();

      expect(user.id, 69);
      expect(user.name, 'abdallah');
      expect(user.email, 'elmohamadydev@gmail.com');
    });

    test('updateProfile() returns updated user', () async {
      final repo = ProfileRepositoryImpl(
        _FakeProfileApi(updateBody: updateProfileEnvelope),
      );

      final user = await repo.updateProfile(
        id: 69,
        name: 'Abdallah',
        email: 'new@example.com',
        phoneCode: '20',
        mobile: '1276586027',
      );

      expect(user.name, 'Abdallah');
      expect(user.email, 'new@example.com');
      expect(user.avatarUrl, contains('capcom.png'));
    });
  });
}
