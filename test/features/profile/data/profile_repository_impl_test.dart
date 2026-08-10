import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/profile/data/profile_api.dart';
import 'package:safaria/features/profile/data/profile_repository_impl.dart';

import 'profile_fixtures.dart';

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({
    this.fetchBody,
    this.updateBody,
    this.onUpdate,
    this.verifyAltPhoneBody,
    this.deleteAccountBody,
    this.deleteAccountError,
  }) : super(Dio());

  final dynamic fetchBody;
  final dynamic updateBody;
  final dynamic verifyAltPhoneBody;
  final dynamic deleteAccountBody;
  final Object? deleteAccountError;
  final void Function(FormData body)? onUpdate;

  @override
  Future<dynamic> fetch() async => fetchBody;

  @override
  Future<dynamic> update(FormData body) async {
    onUpdate?.call(body);
    return updateBody;
  }

  @override
  Future<dynamic> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      verifyAltPhoneBody;

  @override
  Future<dynamic> deleteAccount() async {
    final err = deleteAccountError;
    if (err != null) throw err;
    return deleteAccountBody;
  }
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

    test('updateProfile() attaches avatar multipart when avatarPath is set',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('profile_avatar');
      addTearDown(() => tempDir.delete(recursive: true));
      final avatarFile = File('${tempDir.path}/capcom.png');
      await avatarFile.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);

      FormData? captured;
      final repo = ProfileRepositoryImpl(
        _FakeProfileApi(
          updateBody: updateProfileEnvelope,
          onUpdate: (body) => captured = body,
        ),
      );

      await repo.updateProfile(
        id: 69,
        name: 'Abdallah',
        email: 'new@example.com',
        phoneCode: '20',
        mobile: '1276586027',
        avatarPath: avatarFile.path,
      );

      expect(captured, isNotNull);
      expect(captured!.fields.map((e) => e.key), contains('id'));
      expect(captured!.files.map((e) => e.key), contains('avatar'));
    });

    group('verifyAltPhone', () {
      test('returns the user with the phone now attached', () async {
        const envelope = {
          'status': 200,
          'message': 'User data',
          'errors': <String, dynamic>{},
          'data': {
            'id': 90,
            'name': 'Abdallah',
            'email': 'abdallah@gmail.com',
            'mobile': '1276586027',
            'phonecode': '20',
            'status': 'Active',
            'avatar': '',
            'is_profile_completed': true,
          },
        };

        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(verifyAltPhoneBody: envelope),
        );

        final user = await repo.verifyAltPhone(
          phoneCode: '20',
          mobile: '1276586027',
          code: '1234',
        );

        expect(user.mobile, '1276586027');
        expect(user.isProfileCompleted, isTrue);
      });

      test('throws ApiException on an error envelope', () async {
        const envelope = {
          'status': 400,
          'message': 'Invalid verification code',
          'errors': {
            'code': 'Invalid verification code',
          },
          'data': <String, dynamic>{},
        };

        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(verifyAltPhoneBody: envelope),
        );

        await expectLater(
          repo.verifyAltPhone(
            phoneCode: '20',
            mobile: '1276586027',
            code: '0000',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('deleteAccount', () {
      test('completes when envelope status is 200', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountBody: {
              'status': 200,
              'message': 'Account deleted',
              'errors': <String, dynamic>{},
              'data': <String, dynamic>{},
            },
          ),
        );

        await repo.deleteAccount();
      });

      test('throws ApiException on an error envelope', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountBody: {
              'status': 400,
              'message': 'Cannot delete account',
              'errors': <String, dynamic>{},
              'data': <String, dynamic>{},
            },
          ),
        );

        await expectLater(
          repo.deleteAccount(),
          throwsA(isA<ApiException>()),
        );
      });

      test('throws ApiException on DioException', () async {
        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(
            deleteAccountError: DioException(
              requestOptions: RequestOptions(path: '/profile'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        await expectLater(
          repo.deleteAccount(),
          throwsA(isA<ApiException>()),
        );
      });
    });
  });
}
