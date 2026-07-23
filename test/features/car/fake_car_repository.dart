import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/features/car/domain/repositories/car_repository.dart';

class FakeCarRepository implements CarRepository {
  FakeCarRepository({this.quotesResult});

  List<CarTripQuote>? quotesResult;
  CarSearchParams? lastSearchParams;
  bool searchShouldThrow = false;
  ApiException? searchException;

  static const sampleQuote = CarTripQuote(
    id: 1,
    rounded: false,
    goPrice: 69.87,
    roundPrice: 104.81,
    currency: 'SAR',
    company:  CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
    ),
    fromLocation:  CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation:  CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle:  CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
    ),
  );

  @override
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params) {
    lastSearchParams = params;
    if (searchShouldThrow) {
      throw searchException ??
          const ApiException('Unauthorized', statusCode: 401);
    }
    return Future.value(quotesResult ?? [sampleQuote]);
  }
}
