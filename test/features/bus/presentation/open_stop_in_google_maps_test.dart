import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/presentation/widgets/open_stop_in_google_maps.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  testWidgets('confirming opens Google Maps search URL for the stop', (
    tester,
  ) async {
    Uri? launchedUri;
    const stop = BusStop(
      locationId: 'b2',
      name: 'Zayed',
      cityId: 1,
      cityName: '6th of October',
      latitude: 30.01,
      longitude: 31.02,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => confirmAndOpenStopInGoogleMaps(
                context,
                stop: stop,
                launchUrl: (uri) async {
                  launchedUri = uri;
                  return true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Google Maps'));
    await tester.pumpAndSettle();

    expect(launchedUri, isNotNull);
    expect(launchedUri!.path, '/maps/search/');
    expect(launchedUri!.queryParameters['query'], '30.01,31.02');
  });
}
