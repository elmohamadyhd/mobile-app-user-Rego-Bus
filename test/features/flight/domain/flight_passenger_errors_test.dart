import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_errors.dart';

void main() {
  test('groups indexed keys under their passenger', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.0.documentNumber': ['The document number is invalid.'],
      'passengers.2.firstName': ['The first name is required.'],
    });
    expect(result.keys.toList()..sort(), [0, 2]);
    expect(result[0]!['documentNumber'], 'The document number is invalid.');
    expect(result[2]!['firstName'], 'The first name is required.');
  });

  test('keeps only the first message per field', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.1.birthDate': ['Too old.', 'Also wrong.'],
    });
    expect(result[1]!['birthDate'], 'Too old.');
  });

  test('collects several fields on one passenger', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.1.firstName': ['Required.'],
      'passengers.1.lastName': ['Required.'],
    });
    expect(result[1], hasLength(2));
  });

  test('ignores keys that are not passenger-indexed', () {
    final result = flightPassengerErrorsByIndex({
      'offer_id': ['Expired.'],
      'passengers': ['At least one is required.'],
    });
    expect(result, isEmpty);
  });

  test('null errors yield an empty map', () {
    expect(flightPassengerErrorsByIndex(null), isEmpty);
  });

  test('unparseable index is ignored rather than throwing', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.x.firstName': ['Required.'],
    });
    expect(result, isEmpty);
  });
}
