import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/domain/entities/car_create_order_request.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/domain/repositories/car_repository.dart';

class FakeCarRepository implements CarRepository {
  FakeCarRepository({
    this.quotesResult,
    this.tripResult,
    this.orderResult,
    this.ordersResult,
  });

  List<CarTripQuote>? quotesResult;
  CarTripQuote? tripResult;
  CarOrder? orderResult;
  List<CarOrder>? ordersResult;
  CarSearchParams? lastSearchParams;
  int? lastGetTripId;
  CarCreateOrderRequest? lastCreateRequest;
  int createCallCount = 0;
  bool searchShouldThrow = false;
  bool getTripShouldThrow = false;
  bool createShouldThrow = false;
  bool getOrderShouldThrow = false;
  ApiException? searchException;
  ApiException? getTripException;
  ApiException? createException;
  ApiException? getOrderException;

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

  static const samplePendingOrder = CarOrder(
    id: 39,
    statusText: 'pending',
    statusKind: CarOrderStatusKind.pending,
    price: '1000.00',
    currency: 'EGP',
    rounded: false,
    departureDate: '2026-12-20',
    from: CarOrderCoords(latitude: 30.0314696, longitude: 31.2612288),
    to: CarOrderCoords(
      latitude: 31.182972882989525,
      longitude: 29.894801258559188,
    ),
    trip: sampleQuote,
    invoiceUrl: 'https://eg.myfatoorah.com/EGY/ia/sample',
    transactionStatus: 'pending',
    paymentGateway: 'myfatoorah',
    paymentInvoiceId: '8213800',
    canBeCancel: true,
  );

  static const sampleConfirmedOrder = CarOrder(
    id: 39,
    statusText: 'confirmed',
    statusKind: CarOrderStatusKind.confirmed,
    price: '1000.00',
    currency: 'EGP',
    rounded: false,
    departureDate: '2026-12-20',
    from: CarOrderCoords(latitude: 30.0314696, longitude: 31.2612288),
    to: CarOrderCoords(
      latitude: 31.182972882989525,
      longitude: 29.894801258559188,
    ),
    trip: sampleQuote,
    invoiceUrl: 'https://eg.myfatoorah.com/EGY/ia/sample',
    transactionStatus: 'paid',
    paymentGateway: 'myfatoorah',
    paymentInvoiceId: '8213800',
    canBeCancel: false,
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

  @override
  Future<CarOrder> createOrder(CarCreateOrderRequest request) {
    lastCreateRequest = request;
    createCallCount++;
    if (createShouldThrow) {
      throw createException ?? const ApiException('Failed', statusCode: 500);
    }
    return Future.value(orderResult ?? samplePendingOrder);
  }

  @override
  Future<CarOrder> payOrder({
    required int orderId,
    required CarCreateOrderRequest request,
  }) {
    return Future.value(orderResult ?? samplePendingOrder);
  }

  @override
  Future<CarOrder> cancelOrder(int orderId) {
    return Future.value(
      orderResult ??
          const CarOrder(
            id: 39,
            statusText: 'cancelled',
            statusKind: CarOrderStatusKind.cancelled,
            price: '1000.00',
            currency: 'EGP',
            rounded: false,
            from: CarOrderCoords(latitude: 0, longitude: 0),
            to: CarOrderCoords(latitude: 0, longitude: 0),
            canBeCancel: false,
          ),
    );
  }

  @override
  Future<List<CarOrder>> listOrders() {
    return Future.value(ordersResult ?? [samplePendingOrder]);
  }

  @override
  Future<CarOrder> getOrder(int orderId) {
    if (getOrderShouldThrow) {
      throw getOrderException ?? const ApiException('Failed', statusCode: 500);
    }
    return Future.value(orderResult ?? sampleConfirmedOrder);
  }

  @override
  Future<void> submitReview({
    required int orderId,
    required int rating,
    String? comment,
  }) async {}
}
