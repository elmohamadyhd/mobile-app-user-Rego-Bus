import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/addresses/data/addresses_dto_mapper.dart';

import 'addresses_fixtures.dart';

void main() {
  group('AddressesDtoMapper', () {
    test('pageFromEnvelope parses list + pagination', () {
      final page = AddressesDtoMapper.pageFromEnvelope(listEnvelope);
      expect(page.items, hasLength(1));
      expect(page.items.first.id, 22);
      expect(page.items.first.name, 'Home');
      expect(page.items.first.mapLocation.addressName, '12 El Tahrir St');
      expect(page.items.first.mapLocation.latitude, 24.2222);
      expect(page.currentPage, 1);
      expect(page.hasNextPage, isFalse);
    });

    test('addressFromEnvelope parses single record', () {
      final address = AddressesDtoMapper.addressFromEnvelope(createEnvelope);
      expect(address.id, 23);
      expect(address.name, 'Work');
      expect(address.mapLocation.longitude, 31.37);
    });
  });
}
