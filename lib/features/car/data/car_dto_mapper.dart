import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';

abstract final class CarDtoMapper {
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
