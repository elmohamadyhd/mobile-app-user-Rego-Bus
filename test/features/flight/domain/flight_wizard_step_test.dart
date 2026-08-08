import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';

void main() {
  test('an offer with bundles has four steps', () {
    expect(flightWizardSteps(haveBundles: true), [
      FlightWizardStep.review,
      FlightWizardStep.bundles,
      FlightWizardStep.passengers,
      FlightWizardStep.pay,
    ]);
  });

  test('an offer without bundles omits the bundle step entirely', () {
    final steps = flightWizardSteps(haveBundles: false);
    expect(steps, [
      FlightWizardStep.review,
      FlightWizardStep.passengers,
      FlightWizardStep.pay,
    ]);
    expect(steps.contains(FlightWizardStep.bundles), isFalse);
  });

  test('index reflects position in the derived list, not the enum', () {
    expect(
      flightWizardStepIndex(FlightWizardStep.passengers, haveBundles: false),
      1,
    );
    expect(
      flightWizardStepIndex(FlightWizardStep.passengers, haveBundles: true),
      2,
    );
  });

  test('a step absent from the list has no index', () {
    expect(
      flightWizardStepIndex(FlightWizardStep.bundles, haveBundles: false),
      isNull,
    );
  });
}
