import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

void main() {
  test('sends the chosen bundle per leg', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: {'journey-1': 'RCAI', 'journey-2': 'FCAI'},
      currency: 'EGP',
    );
    expect(body['selectedBundles'], [
      {'journeyKey': 'journey-1', 'selectedBundleCode': 'RCAI'},
      {'journeyKey': 'journey-2', 'selectedBundleCode': 'FCAI'},
    ]);
    expect(body['currency'], 'EGP');
  });

  test('an offer with no bundles sends an empty array, not a missing key', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: const {},
      currency: 'EGP',
    );
    expect(body['selectedBundles'], isEmpty);
    expect(body.containsKey('selectedBundles'), isTrue);
  });

  test('this endpoint spells currency correctly, unlike search', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: const {},
      currency: 'EGP',
    );
    expect(body.containsKey('currency'), isTrue);
    expect(body.containsKey('curreny'), isFalse);
  });
}
