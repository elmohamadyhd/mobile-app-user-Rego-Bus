import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/utils/device_token.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

final flightSavedTravellersStoreProvider =
    Provider<FlightSavedTravellersStore>((ref) {
  return FlightSavedTravellersStore(ref.watch(secureStorageProvider));
});

/// Travellers the rider chose to keep, so a family booking is not retyped
/// every trip.
///
/// This is identity data — full name, birth date, national ID — so it lives
/// in secure storage, and the profile screen must offer a way to delete it.
class FlightSavedTravellersStore {
  const FlightSavedTravellersStore(this._storage);

  final SecureStorage _storage;

  Future<List<FlightPassengerDraft>> read() async {
    final raw = await _storage.readFlightTravellers();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => FlightPassengerDraft.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } on FormatException {
      // A corrupt blob is not worth crashing the passenger form over —
      // the rider simply sees no suggestions.
      return const [];
    }
  }

  /// Saves [draft], assigning an id when it has none. A draft that already
  /// carries a [FlightPassengerDraft.savedId] replaces its stored version.
  Future<FlightPassengerDraft> save(FlightPassengerDraft draft) async {
    final all = List<FlightPassengerDraft>.from(await read());
    // A wall-clock timestamp collides when two travellers are saved back to
    // back — Windows' clock resolution is coarser than a microsecond. The
    // same random generator backing the device token has no such ceiling.
    final withId = draft.savedId != null
        ? draft
        : draft.copyWith(savedId: generateDeviceToken());

    final index = all.indexWhere((t) => t.savedId == withId.savedId);
    if (index == -1) {
      all.add(withId);
    } else {
      all[index] = withId;
    }

    await _write(all);
    return withId;
  }

  Future<void> delete(String savedId) async {
    final all = await read();
    await _write(all.where((t) => t.savedId != savedId).toList());
  }

  Future<void> clear() => _storage.clearFlightTravellers();

  Future<void> _write(List<FlightPassengerDraft> travellers) {
    return _storage.writeFlightTravellers(
      jsonEncode(travellers.map((t) => t.toJson()).toList()),
    );
  }
}
