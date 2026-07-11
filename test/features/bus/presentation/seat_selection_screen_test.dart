import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/seat_selection_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

void main() {
  testWidgets('shows the booking step bar with Seat as the current step',
      (tester) async {
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
          home: SeatSelectionScreen(),
        ),
      ),
    );
    await container
        .read(busBookingProvider.notifier)
        .selectTrip(FakeBusRepository.sampleTrip);
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
