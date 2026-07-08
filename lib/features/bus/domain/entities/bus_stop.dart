import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_stop.freezed.dart';

@freezed
abstract class BusStop with _$BusStop {
  const factory BusStop({
    required String locationId,
    required String name,
    required int cityId,
    required String cityName,
    DateTime? arrivalAt,
    @Default(0) double finalPrice,
    @Default(0) double originalPrice,
  }) = _BusStop;

  const BusStop._();

  static const empty = BusStop(
    locationId: '',
    name: '',
    cityId: 0,
    cityName: '',
  );
}
