import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/data/car_api.dart';
import 'package:safaria/features/car/data/car_dto_mapper.dart';
import 'package:safaria/features/car/domain/entities/car_create_order_request.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/domain/repositories/car_repository.dart';

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
        departDate: params.departDate,
        returnDate: params.returnDate,
      );
      return CarDtoMapper.quotesFromEnvelope(body);
    });
  }

  @override
  Future<CarTripQuote> getTrip(int id) {
    return _guard(() async {
      final body = await _api.getTrip(id);
      return CarDtoMapper.quoteFromDetailsEnvelope(body);
    });
  }

  @override
  Future<CarOrder> createOrder(CarCreateOrderRequest request) {
    return _guard(() async {
      final body = await _api.createOrder(
        CarDtoMapper.createOrderBody(request),
      );
      return CarDtoMapper.orderFromEnvelope(body);
    });
  }

  @override
  Future<CarOrder> payOrder({
    required int orderId,
    required CarCreateOrderRequest request,
  }) {
    return _guard(() async {
      final body = await _api.payOrder(
        orderId: orderId,
        body: CarDtoMapper.createOrderBody(request),
      );
      return CarDtoMapper.orderFromEnvelope(body);
    });
  }

  @override
  Future<CarOrder> cancelOrder(int orderId) {
    return _guard(() async {
      final body = await _api.cancelOrder(orderId);
      return CarDtoMapper.orderFromEnvelope(body);
    });
  }

  @override
  Future<List<CarOrder>> listOrders() {
    return _guard(() async {
      final body = await _api.listOrders();
      return CarDtoMapper.ordersFromEnvelope(body);
    });
  }

  @override
  Future<CarOrder> getOrder(int orderId) {
    return _guard(() async {
      final body = await _api.getOrder(orderId);
      return CarDtoMapper.orderFromEnvelope(body);
    });
  }

  @override
  Future<void> submitReview({
    required int orderId,
    required int rating,
    String? comment,
  }) {
    return _guard(() async {
      final body = await _api.submitReview(
        orderId: orderId,
        rating: rating,
        comment: comment,
      );
      CarDtoMapper.ensureSuccess(body as Map<String, dynamic>);
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
