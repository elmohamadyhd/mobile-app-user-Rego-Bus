import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/utils/order_trip_route_stops.dart';

BusStop _stop({
  required String id,
  required String name,
  DateTime? arrivalAt,
}) {
  return BusStop(
    locationId: id,
    name: name,
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: arrivalAt,
  );
}

void main() {
  test('orders boarding stops by arrival then drop-off stops by arrival', () {
    final result = orderTripRouteStops(
      boardingStops: [
        _stop(id: 'b2', name: 'Ramsis', arrivalAt: DateTime(2026, 2, 10, 8)),
        _stop(id: 'b1', name: 'Sekka', arrivalAt: DateTime(2026, 2, 10, 7)),
      ],
      dropoffStops: [
        _stop(
          id: 'd2',
          name: 'Moharam Bek',
          arrivalAt: DateTime(2026, 2, 10, 12),
        ),
        _stop(
          id: 'd1',
          name: 'Sidi Gaber',
          arrivalAt: DateTime(2026, 2, 10, 11),
        ),
      ],
    );

    expect(result.map((s) => s.name).toList(), [
      'Sekka',
      'Ramsis',
      'Sidi Gaber',
      'Moharam Bek',
    ]);
  });

  test('filters out BusStop.empty entries', () {
    final result = orderTripRouteStops(
      boardingStops: [BusStop.empty, _stop(id: 'b1', name: 'Ramsis')],
      dropoffStops: [BusStop.empty],
    );

    expect(result, hasLength(1));
    expect(result.single.name, 'Ramsis');
  });
}
