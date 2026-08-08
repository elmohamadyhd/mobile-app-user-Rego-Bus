import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_filter_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _carriers = [
  FlightCarrierOption(code: 'NE', name: 'Nile Air', offerCount: 2),
  FlightCarrierOption(code: 'MS', name: 'EgyptAir', offerCount: 1),
];

void main() {
  testWidgets('counts matches live as filters change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlightFilterSheet(
            initial: const FlightOfferFilters(),
            carriers: _carriers,
            priceBounds: const (3000.0, 9000.0),
            matchCount: (filters) => filters.refundableOnly ? 1 : 3,
            onApply: (
              _, {
              required bool directOnly,
              required bool needsSearch,
            }) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show 3 flights'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flight-filter-refundable')));
    await tester.pump();

    expect(find.text('Show 1 flights'), findsOneWidget);
  });
}
