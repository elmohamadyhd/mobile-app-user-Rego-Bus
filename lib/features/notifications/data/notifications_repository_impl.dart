import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/notifications/data/notifications_api.dart';
import 'package:safaria/features/notifications/data/notifications_dto_mapper.dart';
import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';
import 'package:safaria/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._api);

  final NotificationsApi _api;

  @override
  Future<NotificationsPage> list({int page = 1}) => _guard(
        () async => NotificationsDtoMapper.pageFromEnvelope(
          await _api.list(page: page),
        ),
      );

  @override
  Future<void> deleteAll() => _guard(() => _api.deleteAll());

  @override
  Future<void> delete(String id) => _guard(() => _api.delete(id));

  @override
  Future<void> updateFirebaseToken(String token) =>
      _guard(() => _api.updateFirebaseToken(token));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
