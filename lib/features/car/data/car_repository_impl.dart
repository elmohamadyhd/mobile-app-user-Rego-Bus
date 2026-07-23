import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/data/car_api.dart';
import 'package:rego/features/car/data/car_dto_mapper.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/features/car/domain/repositories/car_repository.dart';

class CarRepositoryImpl implements CarRepository {
  CarRepositoryImpl(this._api);

  final CarApi _api;

  @override
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params) {
    return _guard(() async {
      final body = await _api.searchQuotes(
        fromLatitude: params.from.latitude,
        fromLongitude: params.from.longitude,
        toLatitude: params.to.latitude,
        toLongitude: params.to.longitude,
        rounded: params.rounded,
      );
      return CarDtoMapper.quotesFromEnvelope(body);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
