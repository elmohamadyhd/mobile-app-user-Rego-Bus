import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';

final _departure = DateTime(2026, 8, 30);

FlightPassengerDraft _adult({
  String? documentNumber = '29001021234567',
  DateTime? birthDate,
  String? email = 'a@b.com',
  String? phone = '01090510796',
}) {
  return FlightPassengerDraft(
    type: FlightPassengerType.adult,
    title: 'MR',
    firstName: 'Ahmed',
    lastName: 'Mostafa',
    gender: 'M',
    birthDate: birthDate ?? DateTime(1990, 1, 2),
    documentNumber: documentNumber,
    nationalityCode: 'EGY',
    residenceCode: 'EGY',
    addressCountryCode: 'EG',
    addressCityCode: 'CAI',
    addressLine1: 'Street 1',
    addressLine2: 'Apt 1',
    email: email,
    phone: phone,
  );
}

void main() {
  group('age classification', () {
    test('exactly 12 at departure is an adult', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2014, 8, 30),
          departureDate: _departure,
        ),
        FlightPassengerType.adult,
      );
    });

    test('turning 12 the day after departure is still a child', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2014, 8, 31),
          departureDate: _departure,
        ),
        FlightPassengerType.child,
      );
    });

    test('exactly 2 at departure is a child', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2024, 8, 30),
          departureDate: _departure,
        ),
        FlightPassengerType.child,
      );
    });

    test('under 2 at departure is an infant', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2024, 8, 31),
          departureDate: _departure,
        ),
        FlightPassengerType.infant,
      );
    });
  });

  group('completeness', () {
    test('a fully filled adult is missing nothing', () {
      expect(missingFlightPassengerFields(_adult()), isEmpty);
      expect(isFlightPassengerComplete(_adult()), isTrue);
    });

    test('a blank document number is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(documentNumber: null)),
        contains(FlightPassengerField.documentNumber),
      );
    });

    test('whitespace does not count as filled', () {
      expect(
        missingFlightPassengerFields(_adult(documentNumber: '   ')),
        contains(FlightPassengerField.documentNumber),
      );
    });

    test('a middle name is optional', () {
      final draft = _adult().copyWith(middleName: null);
      expect(missingFlightPassengerFields(draft), isEmpty);
    });

    test('a blank email is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(email: null)),
        contains(FlightPassengerField.email),
      );
    });

    test('a blank phone is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(phone: '  ')),
        contains(FlightPassengerField.phone),
      );
    });
  });

  group('type mismatch', () {
    test('a birth date matching the booked type reports no mismatch', () {
      expect(
        flightPassengerTypeMismatch(_adult(), departureDate: _departure),
        isNull,
      );
    });

    test('an adult slot holding a child birth date reports the real type', () {
      final draft = _adult(birthDate: DateTime(2018, 5, 1));
      expect(
        flightPassengerTypeMismatch(draft, departureDate: _departure),
        FlightPassengerType.child,
      );
    });

    test('a draft with no birth date yet reports no mismatch', () {
      final draft = _adult().copyWith(birthDate: null);
      expect(
        flightPassengerTypeMismatch(draft, departureDate: _departure),
        isNull,
      );
    });
  });
}
