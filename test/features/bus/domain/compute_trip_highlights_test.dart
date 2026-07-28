import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';
import 'package:safaria/features/bus/domain/utils/compute_trip_highlights.dart';

BusTripSummary _trip({
  required String id,
  required DateTime depart,
  required DateTime arrive,
  required int priceEgp,
}) {
  return BusTripSummary(
    id: id,
    gatewayId: 'gw',
    operatorName: 'Op',
    category: 'VIP',
    dateTime: depart,
    currency: 'EGP',
    defaultBoardingStop: BusStop(
      locationId: 'b$id',
      name: 'Board',
      cityId: 1,
      cityName: 'Cairo',
      arrivalAt: depart,
    ),
    defaultDropoffStop: BusStop(
      locationId: 'd$id',
      name: 'Drop',
      cityId: 2,
      cityName: 'Alex',
      arrivalAt: arrive,
      finalPrice: priceEgp.toDouble(),
    ),
  );
}

void main() {
  test('empty list yields empty map', () {
    expect(computeTripHighlights(const []), isEmpty);
  });

  test('single trip is bestDeal', () {
    final t = _trip(
      id: 'a',
      depart: DateTime(2026, 7, 10, 8),
      arrive: DateTime(2026, 7, 10, 10),
      priceEgp: 100,
    );
    expect(computeTripHighlights([t])['a'], TripHighlight.bestDeal);
  });

  test('ties mark every cheapest and every fastest; both → bestDeal', () {
    final cheapFast = _trip(
      id: 'cf',
      depart: DateTime(2026, 7, 10, 8),
      arrive: DateTime(2026, 7, 10, 10),
      priceEgp: 100,
    );
    final cheapSlow = _trip(
      id: 'cs',
      depart: DateTime(2026, 7, 10, 9),
      arrive: DateTime(2026, 7, 10, 13),
      priceEgp: 100,
    );
    final priceyFast = _trip(
      id: 'pf',
      depart: DateTime(2026, 7, 10, 10),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 200,
    );
    final map = computeTripHighlights([cheapFast, cheapSlow, priceyFast]);
    expect(map['cf'], TripHighlight.bestDeal);
    expect(map['cs'], TripHighlight.cheapest);
    expect(map['pf'], TripHighlight.fastest);
  });

  test('sortTripsWithHighlights pins bestDeal then other marks then rest', () {
    final rest = _trip(
      id: 'r',
      depart: DateTime(2026, 7, 10, 7),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 300,
    );
    final cheapest = _trip(
      id: 'c',
      depart: DateTime(2026, 7, 10, 9),
      arrive: DateTime(2026, 7, 10, 14),
      priceEgp: 100,
    );
    final best = _trip(
      id: 'b',
      depart: DateTime(2026, 7, 10, 10),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 100,
    );
    final trips = [rest, cheapest, best];
    final highlights = computeTripHighlights(trips);
    final sorted = sortTripsWithHighlights(trips, highlights);
    expect(sorted.map((t) => t.id), ['b', 'c', 'r']);
  });

  test('tripMatchesHighlightFilter unions when both flags set', () {
    expect(
      tripMatchesHighlightFilter(
        highlight: TripHighlight.cheapest,
        cheapest: true,
        fastest: true,
      ),
      isTrue,
    );
    expect(
      tripMatchesHighlightFilter(
        highlight: TripHighlight.fastest,
        cheapest: true,
        fastest: true,
      ),
      isTrue,
    );
    expect(
      tripMatchesHighlightFilter(
        highlight: null,
        cheapest: true,
        fastest: false,
      ),
      isFalse,
    );
  });
}
