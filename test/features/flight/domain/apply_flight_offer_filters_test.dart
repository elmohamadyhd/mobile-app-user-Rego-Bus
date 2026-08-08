import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';

FlightOffer _offer({
  required String id,
  required String carrier,
  required double price,
  String refundability = 'FullyRefundable',
  String? carrierName,
}) {
  final departure = DateTime(2026, 8, 30, 10);
  return FlightOffer(
    offerId: id,
    haveBundles: false,
    canBeHeld: true,
    refundability: refundability,
    journeys: [
      FlightJourney(
        id: 'j-$id',
        origin: 'CAI',
        destination: 'RUH',
        numberOfStops: 0,
        segments: [
          FlightSegment(
            id: 's-$id',
            origin: 'CAI',
            destination: 'RUH',
            departureDateTime: departure,
            arrivalDateTime: departure.add(const Duration(hours: 3)),
            flightTimeInMinutes: 180,
            operatingCarrierCode: carrier,
            operatingCarrierName: carrierName,
            operatingFlightNumber: '100',
            marketingCarrierCode: carrier,
            marketingFlightNumber: '100',
          ),
        ],
      ),
    ],
    totalAmount: price,
    taxesAmount: 0,
    baseAmount: price,
    discountAmount: 0,
    beforeDiscountAmount: price,
    serviceChargeAmount: 0,
    currency: 'EGP',
    priceClasses: const [],
  );
}

void main() {
  final nileCheap =
      _offer(id: '1', carrier: 'NE', price: 3000, carrierName: 'Nile Air');
  final nileDear =
      _offer(id: '2', carrier: 'NE', price: 9000, carrierName: 'Nile Air');
  final egyptair = _offer(id: '3', carrier: 'MS', price: 5000);
  final unknownRefund =
      _offer(id: '4', carrier: 'MS', price: 5500, refundability: 'UnKnown');
  final offers = [nileCheap, nileDear, egyptair, unknownRefund];

  test('carrier options count offers and prefer the named carrier', () {
    final options = flightCarrierOptions(offers);
    expect(options.first.code, 'MS');
    expect(options.first.offerCount, 2);
    expect(options.last.code, 'NE');
    expect(options.last.name, 'Nile Air');
  });

  test('price bounds span the cheapest and dearest offer', () {
    expect(flightPriceBounds(offers), (3000.0, 9000.0));
  });

  test('empty filters return the list untouched', () {
    expect(
      applyFlightOfferFilters(offers, const FlightOfferFilters()),
      same(offers),
    );
  });

  test('carrier filter keeps only matching offers', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(carrierCodes: {'NE'}),
    );
    expect(result.map((o) => o.offerId).toList(), ['1', '2']);
  });

  test('price filter is inclusive at both ends', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(minPrice: 3000, maxPrice: 5000),
    );
    expect(result.map((o) => o.offerId).toList(), ['1', '3']);
  });

  test('refundable only excludes unknown refundability', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(refundableOnly: true),
    );
    expect(result.map((o) => o.offerId).contains('4'), isFalse);
  });

  test('preserving drops carriers absent from the new results', () {
    const filters = FlightOfferFilters(carrierCodes: {'NE', 'MS'});
    final preserved =
        preserveFlightFilters(filters: filters, offers: [egyptair]);
    expect(preserved.carrierCodes, {'MS'});
  });

  test('preserving clamps a touched price range to the new bounds', () {
    const filters = FlightOfferFilters(minPrice: 1000, maxPrice: 20000);
    final preserved = preserveFlightFilters(filters: filters, offers: offers);
    expect(preserved.minPrice, 3000);
    expect(preserved.maxPrice, 9000);
  });

  test('preserving leaves an untouched price range untouched', () {
    const filters = FlightOfferFilters(refundableOnly: true);
    final preserved = preserveFlightFilters(filters: filters, offers: offers);
    expect(preserved.minPrice, isNull);
    expect(preserved.maxPrice, isNull);
    expect(preserved.refundableOnly, isTrue);
  });
}
