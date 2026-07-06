import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/auth/data/auth_api.dart';
import 'package:rego/features/auth/data/auth_repository_impl.dart';
import 'package:rego/features/auth/domain/exceptions/account_not_verified_exception.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.loginBody, this.registerBody}) : super(Dio());

  final dynamic loginBody;
  final dynamic registerBody;

  @override
  Future<dynamic> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      loginBody;

  @override
  Future<dynamic> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    required String firebaseToken,
  }) async =>
      registerBody;
}

void main() {
  group('AuthRepositoryImpl.login', () {
    test('throws ApiException on error envelope with empty data', () async {
      const envelope = {
        'status': 422,
        'message': 'invalid credential',
        'errors': {
          'credentials': 'phone or password in invalid',
        },
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(loginBody: envelope));

      await expectLater(
        repo.login(
          phoneCode: '20',
          mobile: '1554052685',
          password: 'wrong',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.errors?['credentials']?.first,
                'credentials',
                'phone or password in invalid',
              ),
        ),
      );
    });

    test('throws AccountNotVerifiedException when need_verification is true',
        () async {
      const envelope = {
        'status': 200,
        'message': 'OTP code sent',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{},
        'need_verification': true,
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(loginBody: envelope));

      await expectLater(
        repo.login(
          phoneCode: '20',
          mobile: '1276586027',
          password: '123456',
        ),
        throwsA(
          isA<AccountNotVerifiedException>().having(
            (e) => e.message,
            'message',
            'OTP code sent',
          ),
        ),
      );
    });

    test('does not treat need_verfication typo as verification required',
        () async {
      const envelope = {
        'status': 200,
        'message': 'User data',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{},
        'need_verfication': true,
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(loginBody: envelope));

      await expectLater(
        repo.login(
          phoneCode: '20',
          mobile: '1276586027',
          password: '123456',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when data has no api_token', () async {
      const envelope = {
        'status': 200,
        'message': 'User data',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(loginBody: envelope));

      await expectLater(
        repo.login(
          phoneCode: '20',
          mobile: '1554052685',
          password: 'secret',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No auth token found in response',
          ),
        ),
      );
    });
  });

  group('AuthRepositoryImpl.register', () {
    test('throws ApiException on error envelope with field errors', () async {
      const envelope = {
        'status': 400,
        'message': 'قيمة حقل الجوال مُستخدمة من قبل',
        'errors': {
          'mobile': 'قيمة حقل الجوال مُستخدمة من قبل',
        },
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(registerBody: envelope));

      await expectLater(
        repo.register(
          name: 'test',
          email: 'a@b.com',
          phoneCode: '20',
          mobile: '1276586027',
          password: '123456',
          passwordConfirmation: '123456',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.errors?['mobile']?.first,
                'mobile',
                'قيمة حقل الجوال مُستخدمة من قبل',
              ),
        ),
      );
    });
  });
}
