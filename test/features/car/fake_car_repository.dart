import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/domain/repositories/car_repository.dart';

class FakeCarRepository implements CarRepository {
  FakeCarRepository({this.quotesResult, this.tripResult});

  List<CarTripQuote>? quotesResult;
  CarTripQuote? tripResult;
  CarSearchParams? lastSearchParams;
  int? lastGetTripId;
  bool searchShouldThrow = false;
  bool getTripShouldThrow = false;
  ApiException? searchException;
  ApiException? getTripException;

  static const sampleQuote = CarTripQuote(
    id: 1,
    rounded: false,
    goPrice: 69.87,
    roundPrice: 104.81,
    currency: 'SAR',
    company: CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
      refundPolicy: 'Sky Travel',
    ),
    fromLocation: CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation: CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle: CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
      model: 'Matrix',
      year: 2010,
      bigBagsCount: 4,
      smallBagsCount: 1,
      gearType: 'automatic',
    ),
  );

  static const refreshedQuote = CarTripQuote(
    id: 1,
    rounded: true,
    goPrice: 1000,
    roundPrice: 1500,
    currency: 'EGP',
    company: CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
      refundPolicy: 'Sky Travel',
    ),
    fromLocation: CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation: CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle: CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
      model: 'Matrix',
      year: 2010,
      bigBagsCount: 4,
      smallBagsCount: 1,
      gearType: 'automatic',
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

  @override
  Future<CarTripQuote> getTrip(int id) {
    lastGetTripId = id;
    if (getTripShouldThrow) {
      throw getTripException ??
          const ApiException("This record can't be found", statusCode: 404);
    }
    return Future.value(tripResult ?? refreshedQuote);
  }
}
