/// Steps of the flight booking wizard, in flow order.
enum FlightWizardStep { review, bundles, passengers, pay }

/// The steps this booking actually has. Offers without bundles skip that
/// step rather than showing it disabled — a step a rider can never reach is
/// noise, not progress.
List<FlightWizardStep> flightWizardSteps({required bool haveBundles}) {
  return [
    FlightWizardStep.review,
    if (haveBundles) FlightWizardStep.bundles,
    FlightWizardStep.passengers,
    FlightWizardStep.pay,
  ];
}

/// Position of [step] in the derived list, or null when this booking has no
/// such step.
int? flightWizardStepIndex(
  FlightWizardStep step, {
  required bool haveBundles,
}) {
  final index = flightWizardSteps(haveBundles: haveBundles).indexOf(step);
  return index == -1 ? null : index;
}
