import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_feature.freezed.dart';

@freezed
abstract class BusFeature with _$BusFeature {
  const factory BusFeature({
    required String id,
    required String name,
    String? iconUrl,
  }) = _BusFeature;
}
