import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/feature_icon.dart';

void main() {
  testWidgets(
    'uses name heuristics when id resolves to generic check',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeatureIcon(
              feature: BusFeature(
                id: 'ac',
                name: 'Air Conditioner',
              ),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsLight.wind);
    },
  );
}
