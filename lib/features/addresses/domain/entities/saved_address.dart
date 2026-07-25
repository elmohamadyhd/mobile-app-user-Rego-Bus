import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_address.freezed.dart';

@freezed
abstract class MapLocation with _$MapLocation {
  const factory MapLocation({
    required double latitude,
    required double longitude,
    required String addressName,
  }) = _MapLocation;
}

@freezed
abstract class SavedAddress with _$SavedAddress {
  const factory SavedAddress({
    required int id,
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
    String? whatsappShareLink,
  }) = _SavedAddress;
}
