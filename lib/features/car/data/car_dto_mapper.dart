import 'package:intl/intl.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/domain/entities/car_create_order_request.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';

abstract final class CarDtoMapper {
  static final _orderDateFormat = DateFormat('yyyy-MM-dd HH:mm');

  static String formatOrderDate(DateTime date) => _orderDateFormat.format(date);

  static CarCreateOrderRequest createRequestFromSelection({
    required CarTripQuote quote,
    required CarSearchParams params,
  }) {
    final depart = formatOrderDate(params.departDate);
    final destinationDate = params.rounded
        ? formatOrderDate(params.returnDate ?? params.departDate)
        : depart;
    return CarCreateOrderRequest(
      tripId: quote.id,
      rounded: params.rounded,
      departureLatitude: params.from.latitude.toString(),
      departureLongitude: params.from.longitude.toString(),
      departureDate: depart,
      departureName: params.from.label,
      destinationLatitude: params.to.latitude.toString(),
      destinationLongitude: params.to.longitude.toString(),
      destinationDate: destinationDate,
      destinationName: params.to.label,
    );
  }

  static Map<String, dynamic> createOrderBody(CarCreateOrderRequest req) {
    return {
      'trip_id': req.tripId,
      'rounded': req.rounded,
      'departure': {
        'latitude': req.departureLatitude,
        'longitude': req.departureLongitude,
        'date': req.departureDate,
        'name': req.departureName,
      },
      'destination': {
        'latitude': req.destinationLatitude,
        'longitude': req.destinationLongitude,
        'date': req.destinationDate,
        'name': req.destinationName,
      },
    };
  }

  static List<CarOrder> ordersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(orderFromJson).toList();
  }

  static CarOrder orderFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is Map<String, dynamic>) return orderFromJson(data);
    return orderFromJson(const <String, dynamic>{});
  }

  static CarOrder orderFromJson(Map<String, dynamic> json) {
    final statusText = _string(json['status']) ?? '';
    final transaction = json['transaction'];
    String? invoiceUrl;
    String? transactionStatus;
    String? paymentGateway;
    String? paymentInvoiceId;
    if (transaction is Map<String, dynamic>) {
      invoiceUrl = _string(transaction['invoice_url']);
      transactionStatus = _string(transaction['status']);
      paymentGateway = _string(transaction['gateway']);
      final meta = transaction['meta_data'];
      if (meta is Map<String, dynamic>) {
        paymentInvoiceId = _string(meta['invoice_id']);
      }
    }

    final from = json['from'];
    final to = json['to'];
    final tripJson = json['trip'];

    return CarOrder(
      id: _int(json['id']) ?? 0,
      statusText: statusText,
      statusKind: orderStatusKind(statusText),
      price: _string(json['price']) ?? '',
      currency: _string(json['currency']) ?? '',
      rounded: json['rounded'] == true,
      departureDate: _string(json['departure_date']),
      returnDate: _string(json['return_date']),
      from: CarOrderCoords(
        latitude: _double(
              from is Map<String, dynamic> ? from['latitude'] : null,
            ) ??
            0,
        longitude: _double(
              from is Map<String, dynamic> ? from['longitude'] : null,
            ) ??
            0,
      ),
      to: CarOrderCoords(
        latitude: _double(
              to is Map<String, dynamic> ? to['latitude'] : null,
            ) ??
            0,
        longitude: _double(
              to is Map<String, dynamic> ? to['longitude'] : null,
            ) ??
            0,
      ),
      trip: tripJson is Map<String, dynamic> ? quoteFromJson(tripJson) : null,
      invoiceUrl: invoiceUrl,
      transactionStatus: transactionStatus,
      paymentGateway: paymentGateway,
      paymentInvoiceId: paymentInvoiceId,
      canBeCancel: json['can_be_cancel'] == true,
      createdAt: _string(json['created_at']),
    );
  }

  static CarOrderStatusKind orderStatusKind(String status) {
    final code = status.trim().toLowerCase();
    const paid = {
      'confirmed',
      'paid',
      'success',
      'completed',
      'succeeded',
      'in_processing',
    };
    if (paid.contains(code)) return CarOrderStatusKind.confirmed;
    if (code == 'pending') return CarOrderStatusKind.pending;
    if (code == 'cancelled' || code == 'canceled') {
      return CarOrderStatusKind.cancelled;
    }
    return CarOrderStatusKind.unknown;
  }

  static void ensureSuccess(Map<String, dynamic> envelope) {
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  static List<CarTripQuote> quotesFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(quoteFromJson).toList();
  }

  static CarTripQuote quoteFromDetailsEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException.fromEnvelope(envelope);
    }
    return quoteFromJson(data);
  }

  static CarTripQuote quoteFromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final from = json['from_location'];
    final to = json['to_location'];
    final vehicle = json['vehicle'];

    return CarTripQuote(
      id: _int(json['id']) ?? 0,
      rounded: json['rounded'] == true,
      goPrice: _double(json['go_price']) ?? 0,
      roundPrice: _double(json['round_price']) ?? 0,
      currency: _string(json['currency']) ?? '',
      company: company is Map<String, dynamic>
          ? CarCompany(
              id: _int(company['id']) ?? 0,
              name: _string(company['name']) ?? '',
              refundability: company['refundability'] == true,
              refundPolicy: _string(company['refund_policy']),
              logoUrl: _string(company['logo_url']),
            )
          : const CarCompany(id: 0, name: '', refundability: false),
      fromLocation: _namedLocation(from),
      toLocation: _namedLocation(to),
      vehicle: vehicle is Map<String, dynamic>
          ? CarVehicle(
              id: _int(vehicle['id']) ?? 0,
              name: _string(vehicle['name']) ?? '',
              categoryName: _string(vehicle['category_name']) ?? '',
              seatsNumber: _int(vehicle['seats_number']) ?? 0,
              model: _string(vehicle['model']),
              year: _int(vehicle['year']),
              bigBagsCount: _int(vehicle['big_bags_count']),
              smallBagsCount: _int(vehicle['small_bags_count']),
              gearType: _string(vehicle['gear_type']),
              featuredUrl: _string(vehicle['featured_url']),
            )
          : const CarVehicle(
              id: 0,
              name: '',
              categoryName: '',
              seatsNumber: 0,
            ),
    );
  }

  static CarNamedLocation _namedLocation(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CarNamedLocation(
        id: 0,
        name: '',
        latitude: 0,
        longitude: 0,
      );
    }
    return CarNamedLocation(
      id: _int(json['id']) ?? 0,
      name: _string(json['name']) ?? '',
      latitude: _double(json['latitude']) ?? 0,
      longitude: _double(json['longitude']) ?? 0,
    );
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
