import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_city_picker.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

void main() {
  Future<void> pumpPickerHost(
    WidgetTester tester, {
    int? excludeCityId,
    void Function(BusLocation?)? onPicked,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final picked = await showBusCityPicker(
                    context,
                    title: 'From',
                    excludeCityId: excludeCityId,
                  );
                  onPicked?.call(picked);
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows cached locations from repository', (tester) async {
    await pumpPickerHost(tester);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Alexandria'), findsOneWidget);
    expect(find.text('Hurghada'), findsOneWidget);
  });

  testWidgets('filters locations locally as user types', (tester) async {
    await pumpPickerHost(tester);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hur');
    await tester.pump();

    expect(find.text('Hurghada'), findsOneWidget);
    expect(find.text('Cairo'), findsNothing);
    expect(find.text('Alexandria'), findsNothing);
  });

  testWidgets('excludes the city already selected in the other field', (
    tester,
  ) async {
    await pumpPickerHost(tester, excludeCityId: 1);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo'), findsNothing);
    expect(find.text('Alexandria'), findsOneWidget);
  });

  testWidgets('returns tapped location', (tester) async {
    BusLocation? picked;
    await pumpPickerHost(
      tester,
      onPicked: (value) => picked = value,
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alexandria'));
    await tester.pumpAndSettle();

    expect(picked?.id, 2);
    expect(picked?.displayName('en'), 'Alexandria');
  });
}
