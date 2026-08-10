import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/places/place_name_resolver.dart';

void main() {
  group('PlaceNameResolver', () {
    test('prefers known name over street and city', () {
      expect(
        PlaceNameResolver.resolve(
          knownName: 'Cairo Airport',
          street: 'Airport Rd',
          city: 'Cairo',
        ),
        'Cairo Airport',
      );
    });

    test('formats street and city', () {
      expect(
        PlaceNameResolver.resolve(
          street: 'Nile Corniche',
          city: 'Cairo',
        ),
        'Nile Corniche, Cairo',
      );
    });

    test('street only', () {
      expect(
        PlaceNameResolver.resolve(street: 'Nile Corniche'),
        'Nile Corniche',
      );
    });

    test('city only', () {
      expect(
        PlaceNameResolver.resolve(city: 'Cairo'),
        'Cairo',
      );
    });

    test('empty when nothing useful', () {
      expect(PlaceNameResolver.resolve(), '');
      expect(
        PlaceNameResolver.resolve(knownName: '  ', street: '', city: null),
        '',
      );
    });
  });
}
