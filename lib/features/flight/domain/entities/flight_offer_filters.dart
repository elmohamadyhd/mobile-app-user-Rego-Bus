import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_offer_filters.freezed.dart';

/// Filters applied on-device to an already-fetched offer list. Controls that
/// require a fresh search (sort, cabin class, direct-only) live on
/// `FlightSearchParams`, not here.
@freezed
abstract class FlightOfferFilters with _$FlightOfferFilters {
  const FlightOfferFilters._();

  const factory FlightOfferFilters({
    @Default(<String>{}) Set<String> carrierCodes,
    double? minPrice,
    double? maxPrice,
    @Default(false) bool refundableOnly,
  }) = _FlightOfferFilters;

  bool get isEmpty =>
      carrierCodes.isEmpty &&
      minPrice == null &&
      maxPrice == null &&
      !refundableOnly;

  /// Number of active constraints, for the filter button's badge.
  int get activeCount =>
      carrierCodes.length +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (refundableOnly ? 1 : 0);
}

/// A carrier the rider can filter by, derived from the current offers.
@freezed
abstract class FlightCarrierOption with _$FlightCarrierOption {
  const factory FlightCarrierOption({
    required String code,
    String? name,
    String? logoUrl,
    required int offerCount,
  }) = _FlightCarrierOption;
}
