import 'package:safaria/features/car/domain/entities/car_create_order_request.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';

abstract interface class CarRepository {
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params);

  Future<CarTripQuote> getTrip(int id);

  Future<CarOrder> createOrder(CarCreateOrderRequest request);

  Future<CarOrder> payOrder({
    required int orderId,
    required CarCreateOrderRequest request,
  });

  Future<CarOrder> cancelOrder(int orderId);

  Future<List<CarOrder>> listOrders();

  Future<CarOrder> getOrder(int orderId);
}
