import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';

part 'flight_passenger_draft.freezed.dart';
part 'flight_passenger_draft.g.dart';

/// Contact details for the whole booking. The API takes an email and phone
/// per traveller, but in practice these are the booker's — collected once and
/// written onto every passenger at submit.
@freezed
abstract class FlightContactDetails with _$FlightContactDetails {
  const factory FlightContactDetails({
    @Default('') String email,
    @Default('') String phone,
  }) = _FlightContactDetails;
}

/// One traveller as the rider has filled them in so far. Every field is
/// nullable because a draft is valid at any stage of completion — the list
/// screen renders progress from exactly this.
///
/// [savedId] is set only for travellers persisted to secure storage.
@freezed
abstract class FlightPassengerDraft with _$FlightPassengerDraft {
  const factory FlightPassengerDraft({
    required FlightPassengerType type,
    String? savedId,
    String? title,
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? birthDate,
    String? documentNumber,
    String? nationalityCode,
    String? residenceCode,
    String? gender,
    /// Address is required by the live passengers endpoint (Phase 3 Task 1).
    String? addressCountryCode,
    String? addressCityCode,
    String? addressLine1,
    String? addressLine2,
  }) = _FlightPassengerDraft;

  factory FlightPassengerDraft.fromJson(Map<String, dynamic> json) =>
      _$FlightPassengerDraftFromJson(json);
}
