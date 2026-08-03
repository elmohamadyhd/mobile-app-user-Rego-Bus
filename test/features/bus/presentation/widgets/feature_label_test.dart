import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/feature_label.dart';
import 'package:safaria/l10n/app_localizations.dart';

void main() {
  testWidgets('known ids resolve to ARB; unknown uses name', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      featureLabel(l10n, const BusFeature(id: 'wifi', name: 'Wi Fi')),
      'Wi-Fi',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'ac', name: 'Air Conditioner')),
      'A/C',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'dvd', name: 'DVD')),
      'DVD',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'gps', name: 'GPS tracking')),
      'GPS',
    );
    expect(
      featureLabel(
        l10n,
        const BusFeature(id: 'snack-bar', name: 'Snack Bar'),
      ),
      'Snack Bar',
    );
  });
}
