import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/auth/data/auth_api.dart';
import 'package:rego/features/auth/data/auth_repository_impl.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(this._loginBody) : super(Dio());

  final dynamic _loginBody;

  @override
  Future<dynamic> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      _loginBody;
}

void main() {
  group('AuthRepositoryImpl._parseSession', () {
    test('throws ApiException on error envelope with empty data', () async {
      const envelope = {
        'status': 422,
        'message': 'invalid credential',
        'errors': {
          'credentials': 'phone or password in invalid',
        },
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(envelope));

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

    test('throws ApiException when data has no api_token', () async {
      const envelope = {
        'status': 200,
        'message': 'User data',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(envelope));

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
}
