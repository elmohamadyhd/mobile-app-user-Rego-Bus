import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_passenger_counts.freezed.dart';

enum FlightPassengerType { adult, child, infant }

/// Passenger composition chosen in the search form, before any traveller
/// details are known.
@freezed
abstract class FlightPassengerCounts with _$FlightPassengerCounts {
  const FlightPassengerCounts._();

  const factory FlightPassengerCounts({
    @Default(1) int adults,
    @Default(0) int children,
    @Default(0) int infants,
  }) = _FlightPassengerCounts;

  int get total => adults + children + infants;
}
