import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

Future<ProviderContainer> _pumpConfirm(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider.overrideWithValue(FakeBusRepository()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: PassengerConfirmScreen(),
      ),
    ),
  );

  final notifier = container.read(busBookingProvider.notifier);
  await notifier.searchTrips(
    BusSearchParams(
      cityFromId: 1,
      cityToId: 2,
      date: DateTime(2026, 2, 10),
    ),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('16');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the step bar and the full choice recap', (tester) async {
    await _pumpConfirm(tester);

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // Boarding default + terminal drop-off seeded by selectTrip.
    expect(find.text('القللي'), findsOneWidget);
    expect(find.text('ميامي'), findsOneWidget);
    // Selected seat chip.
    expect(find.text('16'), findsOneWidget);
    // Trip date recap.
    expect(find.text('Date'), findsOneWidget);
  });
}
