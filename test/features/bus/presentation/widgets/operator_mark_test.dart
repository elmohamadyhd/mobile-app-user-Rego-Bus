import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_mark.dart';

BusTripSummary _tripWithLogo() {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
  );
  final drop = BusStop(
    locationId: '9',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    finalPrice: 180,
  );
  return BusTripSummary(
    id: '1',
    gatewayId: 'Tazcara',
    operatorName: 'SuperJet',
    operatorLogoUrl: 'https://example.com/superjet.png',
    category: 'Comfort',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    defaultBoardingStop: board,
    defaultDropoffStop: drop,
  );
}

void main() {
  testWidgets(
    'OperatorAvatar uses contain so logos are not cropped',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperatorAvatar(trip: _tripWithLogo()),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
    },
  );

  testWidgets(
    'OperatorMark uses contain so logos are not cropped',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OperatorMark(
              name: 'Horus Bus',
              logoUrl: 'https://example.com/horus.png',
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
    },
  );
}
