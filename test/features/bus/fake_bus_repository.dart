import 'dart:async';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/domain/entities/bus_order.dart';
import 'package:safaria/features/bus/domain/entities/bus_search_params.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_ticket.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/seat_map.dart';
import 'package:safaria/features/bus/domain/repositories/bus_repository.dart';

/// In-memory repository for widget/notifier tests.
class FakeBusRepository implements BusRepository {
  FakeBusRepository({
    this.tripsPage,
    this.tripsPageQueue,
    this.tripByIdResult,
    this.seatMapResult,
    this.ticketResult,
    this.orderStatusResult,
    this.ordersResult,
    this.orderByIdResult,
  });

  BusTripsPage? tripsPage;

  /// Successive `searchTrips` results, one per call. Once the queue runs dry
  /// the last entry repeats — which is what a settled aggregator looks like.
  List<BusTripsPage>? tripsPageQueue;

  /// Full result set per round, which the fake paginates itself using
  /// [perPage]. A round is delimited by a `page: 1` call, so a caller that
  /// pulls pages 1..n counts as one round. Takes precedence over
  /// [tripsPageQueue]; the last round repeats once the list runs dry.
  List<List<BusTripSummary>>? paginatedRounds;

  /// Page size the fake reports and slices by when [paginatedRounds] is set.
  /// Matches the live `/buses/trips` page size.
  int perPage = 15;

  int _roundCursor = -1;

  /// Zero-based indices of `searchTrips` calls that should throw instead.
  Set<int> failingSearchCalls = {};

  /// If set, the next `searchTrips` call waits on this, then clears it.
  Completer<void>? nextSearchTripsHold;

  /// If set, `searchTrips` for [holdSearchTripsPage] waits on this.
  Completer<void>? searchTripsPageHold;

  /// Page number that [searchTripsPageHold] applies to. Ignored when the
  /// hold is null.
  int holdSearchTripsPage = 2;

  int searchTripsCallCount = 0;
  BusTripSummary? tripByIdResult;
  SeatMap? seatMapResult;
  BusTicket? ticketResult;
  BusOrderStatus? orderStatusResult;
  List<BusLocation>? locationsResult;
  int createTicketCallCount = 0;
  BusCreateTicketRequest? lastCreateTicketRequest;
  List<BusOrder>? ordersResult;
  int listOrdersCallCount = 0;
  bool listOrdersShouldThrow = false;
  List<String> cancelOrderCalls = [];
  bool cancelOrderShouldThrow = false;
  final List<({String orderId, int rating, String? comment})>
      submitReviewCalls = [];
  bool submitReviewShouldThrow = false;
  BusOrder? orderByIdResult;
  Completer<BusOrder>? orderByIdCompleter;
  bool orderByIdShouldThrow = false;
  List<String> orderByIdCalls = [];

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
  Future<BusTripsPage> searchTrips(BusSearchParams params,
      {int page = 1}) async {
    final index = searchTripsCallCount++;
    final hold = nextSearchTripsHold;
    nextSearchTripsHold = null;
    if (hold != null) await hold.future;
    final pageHold = searchTripsPageHold;
    if (pageHold != null && page == holdSearchTripsPage) {
      await pageHold.future;
    }
    if (failingSearchCalls.contains(index)) {
      throw const ApiException('search failed', statusCode: 500);
    }
    final rounds = paginatedRounds;
    if (rounds != null && rounds.isNotEmpty) {
      if (page == 1) _roundCursor++;
      final all = rounds[
          _roundCursor < rounds.length ? _roundCursor : rounds.length - 1];
      final lastPage = all.isEmpty ? 1 : ((all.length - 1) ~/ perPage) + 1;
      final start = (page - 1) * perPage;
      final end = start + perPage;
      return BusTripsPage(
        trips: start >= all.length
            ? const []
            : all.sublist(start, end > all.length ? all.length : end),
        currentPage: page,
        lastPage: lastPage,
      );
    }
    final queue = tripsPageQueue;
    if (queue != null && queue.isNotEmpty) {
      return Future.value(
          queue[index < queue.length ? index : queue.length - 1]);
    }
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
    createTicketCallCount++;
    lastCreateTicketRequest = request;
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
  Future<BusOrderStatus> orderStatus(String orderId) async {
    return orderStatusResult ??
        BusOrderStatus(
          orderId: orderId,
          statusCode: 'pending',
          isConfirmed: false,
        );
  }

  @override
  Future<List<BusOrder>> listOrders() async {
    listOrdersCallCount++;
    if (listOrdersShouldThrow) {
      throw const ApiException('Failed to load orders', statusCode: 500);
    }
    return ordersResult ?? const [];
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    cancelOrderCalls.add(orderId);
    if (cancelOrderShouldThrow) {
      throw const ApiException('Cannot cancel', statusCode: 422);
    }
  }

  @override
  Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    submitReviewCalls.add(
      (orderId: orderId, rating: rating, comment: comment),
    );
    if (submitReviewShouldThrow) {
      throw const ApiException(
        'Order must be completed to review',
        statusCode: 400,
      );
    }
  }

  @override
  Future<BusOrder> orderById(String orderId) async {
    orderByIdCalls.add(orderId);
    if (orderByIdCompleter != null) return orderByIdCompleter!.future;
    if (orderByIdShouldThrow) {
      throw const ApiException('Order not found', statusCode: 404);
    }
    return orderByIdResult ?? sampleOrder;
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

  static const sampleOrder = BusOrder(
    orderId: '1475',
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: BusOrderStatusKind.pending,
    dateTimeLabel: '2026-07-30 08:45 AM',
    pickupStopLabel: 'Cairo Main Station',
    dropoffStopLabel: 'Alexandria Terminal',
    ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
    total: 'EGP 219.35',
    canCancel: true,
    cancelUrl: 'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
    gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
    invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    fare: BusOrderFare(
      originalTicketsTotal: 'EGP 205.00',
      discount: 'EGP 0.00',
      walletDiscount: 'EGP 0.00',
      ticketsTotalAfterDiscount: 'EGP 205.00',
      paymentFees: 'EGP 14.35',
      total: 'EGP 219.35',
      currency: 'EGP',
    ),
    paymentGateway: 'Myfatoorah',
    paymentStatusText: 'Pending',
    paymentInvoiceId: '6956732',
    tripId: '145261',
    gatewayOrderId: '5077099',
    tripType: 'Buses',
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
