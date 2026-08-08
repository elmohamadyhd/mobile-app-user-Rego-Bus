import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

/// Fields the passenger endpoint requires. A middle name is deliberately
/// absent — plenty of travel documents have none.
enum FlightPassengerField {
  title,
  firstName,
  lastName,
  gender,
  birthDate,
  documentNumber,
  nationality,
  residence,
  addressCountry,
  addressCity,
  addressLine1,
  addressLine2,
}

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// What this traveller still needs, in the order the form presents it — so
/// the list can name the first gap rather than showing a bare warning dot.
List<FlightPassengerField> missingFlightPassengerFields(
  FlightPassengerDraft draft,
) {
  return [
    if (_blank(draft.title)) FlightPassengerField.title,
    if (_blank(draft.firstName)) FlightPassengerField.firstName,
    if (_blank(draft.lastName)) FlightPassengerField.lastName,
    if (_blank(draft.gender)) FlightPassengerField.gender,
    if (draft.birthDate == null) FlightPassengerField.birthDate,
    if (_blank(draft.documentNumber)) FlightPassengerField.documentNumber,
    if (_blank(draft.nationalityCode)) FlightPassengerField.nationality,
    if (_blank(draft.residenceCode)) FlightPassengerField.residence,
    if (_blank(draft.addressCountryCode)) FlightPassengerField.addressCountry,
    if (_blank(draft.addressCityCode)) FlightPassengerField.addressCity,
    if (_blank(draft.addressLine1)) FlightPassengerField.addressLine1,
    if (_blank(draft.addressLine2)) FlightPassengerField.addressLine2,
  ];
}

bool isFlightPassengerComplete(FlightPassengerDraft draft) =>
    missingFlightPassengerFields(draft).isEmpty;

/// Classifies a traveller by age **at departure**, not today — a child who
/// turns 12 before the flight must travel on an adult fare.
FlightPassengerType classifyFlightPassenger({
  required DateTime birthDate,
  required DateTime departureDate,
}) {
  final years = _completedYears(birthDate, departureDate);
  if (years >= 12) return FlightPassengerType.adult;
  if (years >= 2) return FlightPassengerType.child;
  return FlightPassengerType.infant;
}

/// The traveller's real fare category when it disagrees with the slot they
/// were booked into, or null when they agree or no birth date is set yet.
///
/// The counts were fixed at search and the fare was priced on them, so this
/// is a warning to fix the date or redo the search — never a silent
/// reclassification.
FlightPassengerType? flightPassengerTypeMismatch(
  FlightPassengerDraft draft, {
  required DateTime departureDate,
}) {
  final birthDate = draft.birthDate;
  if (birthDate == null) return null;
  final actual = classifyFlightPassenger(
    birthDate: birthDate,
    departureDate: departureDate,
  );
  return actual == draft.type ? null : actual;
}

int _completedYears(DateTime from, DateTime to) {
  var years = to.year - from.year;
  final hadBirthday =
      to.month > from.month || (to.month == from.month && to.day >= from.day);
  if (!hadBirthday) years -= 1;
  return years;
}
