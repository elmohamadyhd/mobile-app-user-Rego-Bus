import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('displayLabel hides raw coordinates', () {
    const place = CarPlace(
      latitude: 30.99,
      longitude: 30.77,
      label: '30.9928598, 30.7797965',
    );

    expect(CarPlace.looksLikeCoordinates(place.label), isTrue);
    expect(place.displayLabel(l10n), l10n.carPlaceSelectedLocation);
  });

  test('displayLabel returns address when present', () {
    const place = CarPlace(
      latitude: 30.04,
      longitude: 31.23,
      label: 'Cairo, Egypt',
    );

    expect(place.displayLabel(l10n), 'Cairo, Egypt');
  });
}
