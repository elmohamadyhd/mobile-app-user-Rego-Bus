import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

abstract final class BusDtoMapper {
  static void ensureSuccess(Map<String, dynamic> envelope) {
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  static List<BusLocation> locationsFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(locationFromJson)
        .toList();
  }

  static BusLocation locationFromJson(Map<String, dynamic> json) {
    return BusLocation(
      id: _int(json['id']) ?? 0,
      name: _string(json['name']) ?? '',
      nameAr: _string(json['name_ar']),
      nameEn: _string(json['name_en']),
    );
  }

  static BusTripsPage tripsPageFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    final trips = data is List
        ? data.whereType<Map<String, dynamic>>().map(tripFromJson).toList()
        : <BusTripSummary>[];

    final pagination = envelope['pagination'];
    var currentPage = 1;
    var lastPage = 1;
    if (pagination is Map<String, dynamic>) {
      currentPage = _int(pagination['currentPage']) ?? 1;
      lastPage = _int(pagination['lastPage']) ?? 1;
    }

    return BusTripsPage(
      trips: trips,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }

  static BusTripSummary tripFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is Map<String, dynamic>) {
      return tripFromJson(data);
    }
    return emptyTrip();
  }

  static BusTripSummary tripFromJson(Map<String, dynamic> json) {
    final boarding = _stopsFromJson(json['stations_from']);
    final dropoff = _stopsFromJson(json['stations_to']);
    final priceStart = _double(json['price_start_with']) ?? 0;

    final defaultBoarding =
        boarding.isNotEmpty ? boarding.first : BusStop.empty;
    final defaultDropoff = _defaultDropoff(dropoff, priceStart);

    final companyData = json['company_data'];
    String? logo;
    if (companyData is Map<String, dynamic>) {
      logo = _string(companyData['avatar']);
      if (logo != null && logo.isEmpty) logo = null;
    }

    return BusTripSummary(
      id: _string(json['id']) ?? '',
      gatewayId: _string(json['gateway_id']) ?? '',
      operatorName: _string(json['company']) ??
          (companyData is Map<String, dynamic>
              ? _string(companyData['name'])
              : null) ??
          '',
      operatorLogoUrl: logo,
      category: _string(json['category']) ?? '',
      dateTime: _parseDateTime(
            _string(json['date_time']),
            _string(json['date']),
          ) ??
          DateTime.now(),
      currency: _string(json['currency']) ?? 'EGP',
      availableSeats: _int(json['available_seats']) ?? 0,
      priceStartWith: priceStart,
      defaultBoardingStop: defaultBoarding,
      defaultDropoffStop: defaultDropoff,
      boardingStops: boarding,
      dropoffStops: dropoff,
    );
  }

  static BusStop _defaultDropoff(List<BusStop> dropoff, double priceStart) {
    if (dropoff.isEmpty) return BusStop.empty;
    for (final stop in dropoff) {
      if ((stop.finalPrice - priceStart).abs() < 0.01) return stop;
    }
    return dropoff.first;
  }

  static List<BusStop> _stopsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(stopFromJson).toList();
  }

  static BusStop stopFromJson(Map<String, dynamic> json) {
    return BusStop(
      locationId: _string(json['id']) ?? '',
      name: _string(json['name']) ?? '',
      cityId: _int(json['city_id']) ?? 0,
      cityName: _string(json['city_name']) ?? '',
      arrivalAt: _parseDateTime(_string(json['arrival_at']), null),
      finalPrice: _double(json['final_price']) ?? 0,
      originalPrice: _double(json['original_price']) ?? 0,
    );
  }

  static SeatMap seatMapFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      return const SeatMap(
        salon: SeatSalon(id: 0, name: '', rows: 0, columns: 0),
        cells: [],
      );
    }

    final salonJson = data['salon'];
    final salon = salonJson is Map<String, dynamic>
        ? SeatSalon(
            id: _int(salonJson['id']) ?? 0,
            name: _string(salonJson['name']) ?? '',
            rows: _int(salonJson['rows']) ?? 0,
            columns: _int(salonJson['columns']) ?? 0,
            direction: _string(salonJson['direction']) ?? 'ltr',
            levels: _int(salonJson['levels']) ?? 1,
          )
        : const SeatSalon(id: 0, name: '', rows: 0, columns: 0);

    final rawCells = data['seats_map'];
    final cells = rawCells is List
        ? rawCells
            .whereType<Map<String, dynamic>>()
            .map(seatCellFromJson)
            .toList()
        : <SeatMapCell>[];

    return SeatMap(salon: salon, cells: cells);
  }

  static SeatMapCell seatCellFromJson(Map<String, dynamic> json) {
    final className = (_string(json['class']) ?? 'space').toLowerCase();
    return SeatMapCell(
      kind: _cellKind(className),
      id: _string(json['id']),
      seatNo: _string(json['seat_no']),
      category: _string(json['category']),
      level: _int(json['level']) ?? 1,
    );
  }

  static SeatMapCellKind _cellKind(String className) {
    return switch (className) {
      'driver' => SeatMapCellKind.driver,
      'door' => SeatMapCellKind.door,
      'wc' => SeatMapCellKind.wc,
      'available' => SeatMapCellKind.available,
      'booked' => SeatMapCellKind.booked,
      _ => SeatMapCellKind.space,
    };
  }

  static BusTicket ticketFromEnvelope({
    required dynamic body,
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
    required List<String> selectedSeats,
  }) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'] as Map<String, dynamic>? ?? {};

    final ticketsRaw = data['tickets'];
    final lines = ticketsRaw is List
        ? ticketsRaw.whereType<Map<String, dynamic>>().map((t) {
            return BusTicketLine(
              id: _int(t['id']) ?? 0,
              seatNumber: _string(t['seat_number']) ?? '',
              price: _string(t['price']) ?? '0',
            );
          }).toList()
        : <BusTicketLine>[];

    final number = _string(data['number']) ?? _string(data['id']) ?? '';

    // What to load in the payment WebView is the gateway's hosted-checkout page
    // exposed at `payment_data.invoice_url` (e.g. the MyFatoorah invoice page).
    // The top-level `payment_url` is only our backend's `/pay` API endpoint, so
    // it's kept purely as a defensive fallback. The top-level `invoice_url` is a
    // different thing entirely — the e-ticket PDF, downloadable as soon as the
    // order exists (the booking is held ~15 min in `pending` before payment).
    final paymentData = data['payment_data'];
    final gatewayCheckoutUrl = paymentData is Map<String, dynamic>
        ? _string(paymentData['invoice_url'])
        : null;
    final checkoutUrl =
        (gatewayCheckoutUrl != null && gatewayCheckoutUrl.isNotEmpty)
            ? gatewayCheckoutUrl
            : _string(data['payment_url']);

    return BusTicket(
      bookingRef: number,
      orderId: _string(data['id']) ?? '',
      trip: trip,
      fromStop: fromStop,
      toStop: toStop,
      seats: selectedSeats,
      ticketLines: lines,
      total: _string(data['total']) ?? '',
      currency: _string(data['currency']) ?? trip.currency,
      paymentUrl: checkoutUrl,
      cancelUrl: _string(data['cancel_url']),
      invoiceUrl: _string(data['invoice_url']),
      statusCode: _string(data['status_code']),
      issuedAt: DateTime.now(),
    );
  }

  static BusOrderStatus orderStatusFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'] as Map<String, dynamic>? ?? {};

    final statusCode = _string(data['status_code']) ?? '';
    final isConfirmedFlag = _int(data['is_confirmed']) ?? 0;

    return BusOrderStatus(
      orderId: _string(data['id']) ?? '',
      statusCode: statusCode,
      isConfirmed: isPaidStatus(statusCode, isConfirmedFlag),
      total: _string(data['total']),
      paymentUrl: _string(data['payment_url']),
    );
  }

  /// Whether an order's status represents a completed/paid booking.
  ///
  /// ⚠️ Backend dependency: the exact set of "paid" status codes isn't
  /// documented — samples only show `"pending"`. We treat `is_confirmed == 1`
  /// or any of the common success codes as paid. Adjust here once the backend
  /// confirms its vocabulary.
  static bool isPaidStatus(String statusCode, int isConfirmedFlag) {
    if (isConfirmedFlag == 1) return true;
    const paid = {'confirmed', 'paid', 'success', 'completed', 'succeeded'};
    return paid.contains(statusCode.trim().toLowerCase());
  }

  static List<BusOrder> ordersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(orderFromJson).toList();
  }

  static BusOrder orderFromJson(Map<String, dynamic> json) {
    final companyData = json['company_data'];
    String? logo;
    String? companyName;
    if (companyData is Map<String, dynamic>) {
      logo = _string(companyData['avatar']);
      if (logo != null && logo.isEmpty) logo = null;
      companyName = _string(companyData['name']);
    }

    final statusCode = _string(json['status_code']) ?? '';
    final isConfirmedFlag = _int(json['is_confirmed']) ?? 0;

    final ticketsRaw = json['tickets'];
    final seats = ticketsRaw is List
        ? ticketsRaw
            .whereType<Map<String, dynamic>>()
            .map((t) => _string(t['seat_number']) ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final paymentData = json['payment_data'];
    final gatewayCheckoutUrl = paymentData is Map<String, dynamic>
        ? _string(paymentData['invoice_url'])
        : null;

    final pickupStopLabel = _stationName(json['station_from']);
    final dropoffStopLabel = _stationName(json['station_to']);

    return BusOrder(
      orderId: _string(json['id']) ?? '',
      bookingNumber: _string(json['number']) ?? '',
      operatorName: _string(json['company_name']) ?? companyName ?? '',
      operatorLogoUrl: logo,
      category: _string(json['category']) ?? '',
      statusText: _string(json['status']) ?? '',
      statusKind: orderStatusKind(statusCode, isConfirmedFlag),
      dateTimeLabel: _string(json['date_time']) ?? _string(json['date']) ?? '',
      pickupStopLabel: pickupStopLabel,
      dropoffStopLabel: dropoffStopLabel,
      seats: seats,
      total: _string(json['total']) ?? '',
      canCancel: json['can_be_cancel'] == true,
      gatewayCheckoutUrl:
          (gatewayCheckoutUrl != null && gatewayCheckoutUrl.isNotEmpty)
              ? gatewayCheckoutUrl
              : null,
      invoiceUrl: _string(json['invoice_url']),
    );
  }

  /// Same documented-uncertainty caveat as [isPaidStatus]: only `pending`
  /// appears in the sample data. `is_confirmed == 1` always wins; unrecognized
  /// codes fall back to [BusOrderStatusKind.unknown] rather than being
  /// guessed into a destructive or positive bucket.
  static BusOrderStatusKind orderStatusKind(
    String statusCode,
    int isConfirmedFlag,
  ) {
    if (isConfirmedFlag == 1) return BusOrderStatusKind.confirmed;
    final code = statusCode.trim().toLowerCase();
    const confirmedCodes = {
      'confirmed',
      'paid',
      'success',
      'completed',
      'succeeded',
    };
    const cancelledCodes = {
      'cancelled',
      'canceled',
      'expired',
      'failed',
      'refunded',
    };
    if (confirmedCodes.contains(code)) return BusOrderStatusKind.confirmed;
    if (cancelledCodes.contains(code)) return BusOrderStatusKind.cancelled;
    if (code == 'pending') return BusOrderStatusKind.pending;
    return BusOrderStatusKind.unknown;
  }

  static Map<String, dynamic> createTicketBody(BusCreateTicketRequest req) {
    return {
      'from_city_id': req.fromCityId,
      'to_city_id': req.toCityId,
      'from_location_id': req.fromLocationId,
      'to_location_id': req.toLocationId,
      'date': req.date,
      'seats': req.seats
          .map(
            (s) => {
              'seat_type_id': s.seatTypeId,
              'seat_id': s.seatId,
            },
          )
          .toList(),
      'payment_method': req.paymentMethod,
      'currency': req.currency,
    };
  }

  static BusTripSummary emptyTrip() => BusTripSummary(
        id: '',
        gatewayId: '',
        operatorName: '',
        category: '',
        dateTime: DateTime.now(),
        currency: 'EGP',
        defaultBoardingStop: BusStop.empty,
        defaultDropoffStop: BusStop.empty,
      );

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static String? _stationName(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final name = _string(value['name']);
    if (name == null || name.trim().isEmpty) return null;
    return name;
  }

  static DateTime? _parseDateTime(String? primary, String? fallbackDate) {
    final raw = primary ?? fallbackDate;
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.replaceAll(' am', ' AM').replaceAll(' pm', ' PM');
    final patterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd h:mm a',
      'yyyy-MM-dd',
    ];
    for (final pattern in patterns) {
      try {
        return DateFormatPattern.parse(pattern, normalized);
      } catch (_) {
        continue;
      }
    }
    return DateTime.tryParse(normalized.replaceAll(' ', 'T'));
  }
}

/// Minimal date parsing without importing intl in the mapper tests.
abstract final class DateFormatPattern {
  static DateTime parse(String pattern, String value) {
    if (pattern == 'yyyy-MM-dd HH:mm:ss') {
      return DateTime.parse(value.replaceFirst(' ', 'T'));
    }
    if (pattern == 'yyyy-MM-dd HH:mm') {
      return DateTime.parse(value.replaceFirst(' ', 'T'));
    }
    if (pattern == 'yyyy-MM-dd h:mm a') {
      final parts = value.split(' ');
      if (parts.length >= 3) {
        final datePart = parts[0];
        final timePart = parts[1];
        final ampm = parts[2].toUpperCase();
        final hm = timePart.split(':');
        var hour = int.parse(hm[0]);
        final minute = int.parse(hm[1]);
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        final date = DateTime.parse(datePart);
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    }
    if (pattern == 'yyyy-MM-dd') {
      return DateTime.parse(value);
    }
    throw const FormatException('Unsupported pattern');
  }
}
