import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

const _draft = FlightPassengerDraft(
  type: FlightPassengerType.adult,
  title: 'MRS',
  firstName: 'Mona',
  lastName: 'Ahmed',
  gender: 'F',
  documentNumber: '29203141234567',
  nationalityCode: 'EGY',
  residenceCode: 'EGY',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('an empty store reads as an empty list', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    expect(await store.read(), isEmpty);
  });

  test('a saved traveller round-trips with an id assigned', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final saved = await store.save(_draft);
    expect(saved.savedId, isNotNull);

    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.firstName, 'Mona');
    expect(all.first.documentNumber, '29203141234567');
  });

  test('saving an already-saved traveller updates rather than duplicates',
      () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final saved = await store.save(_draft);
    await store.save(saved.copyWith(lastName: 'Hassan'));

    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.lastName, 'Hassan');
  });

  test('delete removes only the named traveller', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final first = await store.save(_draft);
    await store.save(_draft.copyWith(firstName: 'Youssef'));

    await store.delete(first.savedId!);
    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.firstName, 'Youssef');
  });

  test('corrupt stored json reads as empty rather than throwing', () async {
    final storage = SecureStorage();
    await storage.writeFlightTravellers('not json');
    final store = FlightSavedTravellersStore(storage);
    expect(await store.read(), isEmpty);
  });
}
