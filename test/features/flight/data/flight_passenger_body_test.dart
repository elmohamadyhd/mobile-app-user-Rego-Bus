import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

final _mona = FlightPassengerDraft(
  type: FlightPassengerType.adult,
  title: 'MRS',
  firstName: 'Mona',
  middleName: 'Ali',
  lastName: 'Ahmed',
  gender: 'F',
  birthDate: DateTime(1992, 3, 14),
  documentNumber: '29203141234567',
  nationalityCode: 'EGY',
  residenceCode: 'EGY',
  addressCountryCode: 'EG',
  addressCityCode: 'CAI',
  addressLine1: 'Street 1',
  addressLine2: 'Apt 1',
  email: 'mona@example.com',
  phone: '01090510796',
);

void main() {
  test('builds one entry per passenger with that traveller email and phone', () {
    final second = _mona.copyWith(
      firstName: 'Omar',
      email: 'omar@example.com',
      phone: '01111111111',
    );
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona, second],
    );
    final list = body['passengers'] as List;
    expect(list, hasLength(2));

    final first = list.first as Map<String, dynamic>;
    expect(first['title'], 'MRS');
    expect(first['firstName'], 'Mona');
    expect(first['birthDate'], '1992-03-14');
    expect(first['passengerTypeCode'], 'ADT');
    expect(first['nationalityCountryCode'], 'EGY');
    expect(first['email'], 'mona@example.com');
    expect(first['phone'], '01090510796');
    expect(first['address'], {
      'countryCode': 'EG',
      'cityCode': 'CAI',
      'line1': 'Street 1',
      'line2': 'Apt 1',
    });

    final other = list[1] as Map<String, dynamic>;
    expect(other['email'], 'omar@example.com');
    expect(other['phone'], '01111111111');
  });

  test('a null middle name is sent as an empty string, not omitted', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona.copyWith(middleName: null)],
    );
    final first = (body['passengers'] as List).first as Map<String, dynamic>;
    expect(first['middleName'], '');
  });

  test('maps each passenger type to its wire code', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [
        _mona,
        _mona.copyWith(type: FlightPassengerType.child),
        _mona.copyWith(type: FlightPassengerType.infant),
      ],
    );
    expect(
      (body['passengers'] as List)
          .map((p) => (p as Map)['passengerTypeCode'])
          .toList(),
      ['ADT', 'CHD', 'INF'],
    );
  });

  test('null email and phone are sent as empty strings', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona.copyWith(email: null, phone: null)],
    );
    final first = (body['passengers'] as List).first as Map<String, dynamic>;
    expect(first['email'], '');
    expect(first['phone'], '');
  });

  test('reads the new offer id out of the response envelope', () {
    final offerId = FlightDtoMapper.offerIdFromEnvelope({
      'status': 200,
      'message': 'Passengers added',
      'data': {'offerId': 'OFFER_C'},
    });
    expect(offerId, 'OFFER_C');
  });
}
