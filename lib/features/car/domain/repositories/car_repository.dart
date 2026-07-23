import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';

abstract interface class CarRepository {
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params);
}
