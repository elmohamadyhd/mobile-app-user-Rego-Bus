import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_search_params.freezed.dart';

abstract final class BusCurrency {
  static const defaultCode = 'EGP';
}

@freezed
abstract class BusSearchParams with _$BusSearchParams {
  const factory BusSearchParams({
    required int cityFromId,
    required int cityToId,
    required DateTime date,
    @Default(1) int passengers,
    @Default(BusCurrency.defaultCode) String currency,
  }) = _BusSearchParams;
}
