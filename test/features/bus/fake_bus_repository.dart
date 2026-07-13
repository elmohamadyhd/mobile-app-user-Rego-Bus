import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

/// In-memory repository for widget/notifier tests.
class FakeBusRepository implements BusRepository {
  FakeBusRepository({
    this.tripsPage,
    this.tripByIdResult,
    this.seatMapResult,
    this.ticketResult,
    this.orderStatusResult,
  });

  BusTripsPage? tripsPage;
  BusTripSummary? tripByIdResult;
  SeatMap? seatMapResult;
  BusTicket? ticketResult;
  BusOrderStatus? orderStatusResult;
  List<BusLocation>? locationsResult;

  @override
  Future<List<BusLocation>> listLocations() async {
    return locationsResult ?? sampleLocations;
  }

  static const sampleLocations = <BusLocation>[
    BusLocation(
      id: 1,
      name: 'القاهره',
      nameAr: 'القاهره',
      nameEn: 'Cairo',
    ),
    BusLocation(
      id: 2,
      name: 'الاسكندريه',
      nameAr: 'الاسكندريه',
      nameEn: 'Alexandria',
    ),
    BusLocation(
      id: 4,
      name: 'الغردقه',
      nameAr: 'الغردقه',
      nameEn: 'Hurghada',
    ),
  ];

  @override
  Future<BusTripsPage> searchTrips(BusSearchParams params, {int page = 1}) {
    return Future.value(
      tripsPage ??
          const BusTripsPage(
            trips: [],
            currentPage: 1,
            lastPage: 1,
          ),
    );
  }

  @override
  Future<BusTripSummary> tripById(
    String tripId, {
    required String currency,
  }) async {
    return tripByIdResult ?? sampleTrip;
  }

  @override
  Future<SeatMap> seatMap({
    required String tripId,
    required int fromCityId,
    required int toCityId,
    required String fromLocationId,
    required String toLocationId,
    required String date,
  }) async {
    return seatMapResult ?? sampleSeatMap;
  }

  @override
  Future<BusTicket> createTicket(
    BusCreateTicketRequest request, {
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
  }) async {
    return ticketResult ??
        BusTicket(
          bookingRef: '000001',
          orderId: '1',
          trip: trip,
          fromStop: fromStop,
          toStop: toStop,
          seats: request.seats.map((s) => s.seatId).toList(),
          ticketLines: const [],
          total: '100 EGP',
          currency: 'EGP',
          issuedAt: DateTime(2026, 7, 10),
        );
  }

  @override
  Future<BusOrderStatus> orderStatus(
    String orderId, {
    required String currency,
  }) async {
    return orderStatusResult ??
        BusOrderStatus(
          orderId: orderId,
          statusCode: 'pending',
          isConfirmed: false,
        );
  }

  static final sampleTrip = BusTripSummary(
    id: '290545',
    gatewayId: 'Tazcara',
    operatorName: 'النورس للنقل البري',
    category: 'VIP',
    dateTime: DateTime(2025, 2, 10, 7),
    currency: 'EGP',
    availableSeats: 6,
    priceStartWith: 148.5,
    defaultBoardingStop: const BusStop(
      locationId: '985052',
      name: 'القللي',
      cityId: 1,
      cityName: 'القاهره',
      arrivalAt: null,
    ),
    defaultDropoffStop: const BusStop(
      locationId: '985053',
      name: 'محرم بك',
      cityId: 2,
      cityName: 'الاسكندريه',
      finalPrice: 148.5,
      originalPrice: 150,
    ),
    boardingStops: const [
      BusStop(
        locationId: '985052',
        name: 'القللي',
        cityId: 1,
        cityName: 'القاهره',
      ),
    ],
    dropoffStops: const [
      BusStop(
        locationId: '985053',
        name: 'محرم بك',
        cityId: 2,
        cityName: 'الاسكندريه',
        finalPrice: 148.5,
        originalPrice: 150,
      ),
      BusStop(
        locationId: '985054',
        name: 'ميامي',
        cityId: 2,
        cityName: 'الاسكندريه',
        finalPrice: 175,
        originalPrice: 180,
      ),
    ],
  );

  static const sampleSeatMap = SeatMap(
    salon: SeatSalon(id: 1, name: 'Express', rows: 2, columns: 3),
    cells: [
      SeatMapCell(kind: SeatMapCellKind.driver),
      SeatMapCell(kind: SeatMapCellKind.space),
      SeatMapCell(kind: SeatMapCellKind.space),
      SeatMapCell(
        kind: SeatMapCellKind.available,
        id: '16',
        seatNo: '16',
      ),
      SeatMapCell(kind: SeatMapCellKind.booked, id: '15', seatNo: '15'),
      SeatMapCell(kind: SeatMapCellKind.space),
    ],
  );
}
