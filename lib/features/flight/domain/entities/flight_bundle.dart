import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_bundle.freezed.dart';

/// A bundle's price for one passenger type.
///
/// The wire field is `fee_mount` — a backend typo for fee amount, mapped to
/// [feeAmount] here rather than propagated.
@freezed
abstract class FlightBundlePrice with _$FlightBundlePrice {
  const factory FlightBundlePrice({
    required String passengerTypeCode,
    required double totalAmount,
    @Default(0) double taxesAmount,
    @Default(0) double feeAmount,
    String? currency,
    String? bundleReferences,
  }) = _FlightBundlePrice;
}

@freezed
abstract class FlightBundle with _$FlightBundle {
  const factory FlightBundle({
    required String code,
    required String name,
    required List<FlightBundlePrice> prices,
    @Default(<String>[]) List<String> includedServices,
  }) = _FlightBundle;
}

/// The bundles offered for one leg. [offerJourneyId] is the `journeyKey` sent
/// back when creating the order.
@freezed
abstract class FlightJourneyBundles with _$FlightJourneyBundles {
  const factory FlightJourneyBundles({
    required String offerJourneyId,
    required List<FlightBundle> bundles,
  }) = _FlightJourneyBundles;
}
