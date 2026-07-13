import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';

part 'bus_trip.freezed.dart';

/// Placeholder amenities until the API exposes real data.
abstract final class BusPlaceholderAmenities {
  static const values = ['Wi-Fi', 'A/C', 'Sockets', 'Water'];
}

@freezed
abstract class BusTripSummary with _$BusTripSummary {
  const factory BusTripSummary({
    required String id,
    required String gatewayId,
    required String operatorName,
    String? operatorLogoUrl,
    required String category,
    required DateTime dateTime,
    required String currency,
    @Default(0) int availableSeats,
    @Default(0) double priceStartWith,
    required BusStop defaultBoardingStop,
    required BusStop defaultDropoffStop,
    @Default([]) List<BusStop> boardingStops,
    @Default([]) List<BusStop> dropoffStops,
    @Default(BusPlaceholderAmenities.values) List<String> amenities,
  }) = _BusTripSummary;

  const BusTripSummary._();

  /// Merges non-empty fields from [detail] onto this cached search object.
  BusTripSummary mergeEnrichment(BusTripSummary detail) {
    return copyWith(
      gatewayId: detail.gatewayId.isNotEmpty ? detail.gatewayId : gatewayId,
      operatorName:
          detail.operatorName.isNotEmpty ? detail.operatorName : operatorName,
      operatorLogoUrl: detail.operatorLogoUrl ?? operatorLogoUrl,
      category: detail.category.isNotEmpty ? detail.category : category,
      currency: detail.currency.isNotEmpty ? detail.currency : currency,
      availableSeats:
          detail.availableSeats > 0 ? detail.availableSeats : availableSeats,
      priceStartWith:
          detail.priceStartWith > 0 ? detail.priceStartWith : priceStartWith,
      defaultBoardingStop:
          _mergeStop(defaultBoardingStop, detail.defaultBoardingStop),
      defaultDropoffStop:
          _mergeStop(defaultDropoffStop, detail.defaultDropoffStop),
      boardingStops: detail.boardingStops.isNotEmpty
          ? detail.boardingStops
          : boardingStops,
      dropoffStops:
          detail.dropoffStops.isNotEmpty ? detail.dropoffStops : dropoffStops,
    );
  }

  BusStop _mergeStop(BusStop cached, BusStop incoming) {
    if (incoming.locationId.isEmpty) return cached;
    return incoming;
  }

  String get operatorCode {
    final trimmed = operatorName.trim();
    if (trimmed.isEmpty) return 'B';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }

  String get serviceClass => category;

  DateTime get departTime => defaultBoardingStop.arrivalAt ?? dateTime;

  DateTime get arriveTime => defaultDropoffStop.arrivalAt ?? dateTime;

  /// Last drop-off on the route — used for search-result card display only.
  BusStop get terminalDropoffStop =>
      dropoffStops.isNotEmpty ? dropoffStops.last : defaultDropoffStop;

  DateTime get terminalArriveTime =>
      terminalDropoffStop.arrivalAt ?? dateTime;

  String get terminalArriveLabel => _formatTime(terminalArriveTime);

  String get terminalDurationLabel {
    final diff = terminalArriveTime.difference(departTime).inMinutes;
    final mins = diff > 0 ? diff : 0;
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Fare for the last drop-off — used on search cards and cheapest sort.
  double get terminalFare => terminalDropoffStop.finalPrice;

  int get terminalPriceEgp => terminalFare.round();

  int get durationMin {
    final diff = arriveTime.difference(departTime).inMinutes;
    return diff > 0 ? diff : 0;
  }

  int get stopsCount => boardingStops.length + dropoffStops.length;

  double get defaultFare => defaultDropoffStop.finalPrice;

  int get priceEgp => defaultFare.round();

  int get seatsLeft => availableSeats;

  String get departLabel => _formatTime(departTime);

  String get arriveLabel => _formatTime(arriveTime);

  String get durationLabel {
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
