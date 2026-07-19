import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/seat_selection_screen.dart';
import 'package:rego/features/bus/presentation/widgets/bus_images_fab.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

const _mismatchedIdSeatMap = SeatMap(
  salon: SeatSalon(id: 1, name: 'Express', rows: 2, columns: 3),
  cells: [
    SeatMapCell(kind: SeatMapCellKind.driver),
    SeatMapCell(kind: SeatMapCellKind.space),
    SeatMapCell(kind: SeatMapCellKind.space),
    SeatMapCell(
      kind: SeatMapCellKind.available,
      id: '9387818',
      seatNo: '24',
    ),
    SeatMapCell(kind: SeatMapCellKind.booked, id: '15', seatNo: '15'),
    SeatMapCell(kind: SeatMapCellKind.space),
  ],
);

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

  testWidgets(
    'bottom panel shows seat_no label when internal id differs',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          busRepositoryProvider.overrideWithValue(
            FakeBusRepository(seatMapResult: _mismatchedIdSeatMap),
          ),
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

      final notifier = container.read(busBookingProvider.notifier);
      await notifier.searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 2, 10),
        ),
      );
      await notifier.selectTrip(FakeBusRepository.sampleTrip);
      await notifier.loadSeats();
      notifier.toggleSeat('9387818');
      await tester.pumpAndSettle();

      expect(find.text('24'), findsWidgets);
      expect(find.text('9387818'), findsNothing);
    },
  );

  testWidgets('hides bus images FAB when trip has no bus image', (tester) async {
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

    expect(find.byType(BusImagesFab), findsNothing);
  });

  testWidgets('shows bus images FAB and sheet when trip has bus image',
      (tester) async {
    final tripWithImage = FakeBusRepository.sampleTrip.copyWith(
      busImageUrl: 'https://example.com/bus.jpeg',
    );
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

    await container.read(busBookingProvider.notifier).searchTrips(
          BusSearchParams(
            cityFromId: 1,
            cityToId: 2,
            date: DateTime(2026, 2, 10),
          ),
        );
    await container.read(busBookingProvider.notifier).selectTrip(tripWithImage);
    await container.read(busBookingProvider.notifier).loadSeats();
    await tester.pumpAndSettle();

    expect(find.byType(BusImagesFab), findsOneWidget);
    expect(find.byIcon(AppIcons.eye), findsOneWidget);

    await tester.tap(find.byType(BusImagesFab));
    await tester.pumpAndSettle();

    expect(find.text('Bus photos'), findsOneWidget);
  });
}
