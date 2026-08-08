import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_country.freezed.dart';

/// Which ISO width the passenger endpoint accepts for
/// `nationalityCountryCode` and `residenceCountryCode`.
///
/// Settled by the live spike in Phase 3 Task 1. If that answer ever turns out
/// wrong, this constant and [FlightCountry.passengerCode] are the only places
/// that need to change.
const kPassengerCountryCodeWidth = FlightCountryCodeWidth.iso3;

enum FlightCountryCodeWidth { iso2, iso3 }

/// A country from `GET /countries`. Carries both ISO widths because the app
/// needs each in a different place: the passenger fields take one width, and
/// `address.countryCode` takes `iso2`.
@freezed
abstract class FlightCountry with _$FlightCountry {
  const FlightCountry._();

  const factory FlightCountry({
    required String name,
    required String iso2,
    required String iso3,
    required String phoneCode,
  }) = _FlightCountry;

  /// The value to send in the passenger body.
  String get passengerCode => switch (kPassengerCountryCodeWidth) {
        FlightCountryCodeWidth.iso2 => iso2,
        FlightCountryCodeWidth.iso3 => iso3,
      };
}
