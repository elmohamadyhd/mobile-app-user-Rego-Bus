import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_settings.freezed.dart';

/// The slice of `GET /settings` the booking flow needs.
///
/// There is one gateway and one booking currency, so neither is presented as
/// a choice — no payment-method picker, no currency picker.
@freezed
abstract class FlightSettings with _$FlightSettings {
  const factory FlightSettings({
    @Default('EGP') String bookingCurrency,
    @Default('') String paymentGateway,
  }) = _FlightSettings;
}
