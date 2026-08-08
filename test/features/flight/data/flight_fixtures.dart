/// Trimmed from a live GET /flights/iata?search=CAI response (200).
const iataAirportsEnvelope = {
  'status': 200,
  'message': 'Airports list',
  'errors': <String, dynamic>{},
  'data': [
    {
      'id': 30325,
      'name': 'Cairo Intl Airport',
      'city': 'Cairo',
      'country': 'EGYPT',
      'iata_code': 'CAI',
      'icao_code': 'HECA',
      'country_code': 'EG',
      'latitude': 30.04998,
      'longitude': 31.2486,
    },
    {
      'id': 30326,
      'name': 'Capital International Airport',
      'city': 'Cairo',
      'country': 'EGYPT',
      'iata_code': 'CCE',
      'icao_code': null,
      'country_code': 'EG',
      'latitude': null,
      'longitude': null,
    },
  ],
  'pagination': {
    'total': 21,
    'lastPage': 1,
    'perPage': 50,
    'currentPage': 1,
    'nextPageUrl': 'https://demo.safaria.travel/api/v1/flights/iata?page=2',
    'previousPageUrl': null,
  },
};

/// Trimmed from a live GET /flights/airports/search?term=دبي response (200).
const airportSuggestionsEnvelope = {
  'status': 200,
  'message': 'Airports fetched successfully',
  'errors': <String, dynamic>{},
  'data': [
    {
      'iata_code': 'DXB',
      'name': 'All Airport',
      'city': 'Dubai',
      'country_code': 'AE',
      'country': 'UNITED ARAB EMIRATES',
      'latitude': 25.26948,
      'longitude': 55.30883,
      'is_domestic': false,
      'is_all_airport': true,
      'ranking': 179,
    },
    {
      'iata_code': 'DXB',
      'name': 'Dubai Intl Airport',
      'city': 'Dubai',
      'country_code': 'AE',
      'country': 'UNITED ARAB EMIRATES',
      'latitude': 25.26948,
      'longitude': 55.30883,
      'is_domestic': false,
      'is_all_airport': false,
      'ranking': 124,
    },
  ],
};

const airportSuggestionsRequiredTermEnvelope = {
  'status': 400,
  'message': 'The term field is required.',
  'errors': {'term': 'The term field is required.'},
  'data': <String, dynamic>{},
};

/// Trimmed from a live POST /flights/search response (200, one-way, one offer).
const flightSearchEnvelope = {
  'status': 200,
  'message': 'Flight search results',
  'errors': <String, dynamic>{},
  'data': [
    {
      'offerId': 'offer-abc',
      'haveBundles': true,
      'canBeHeld': false,
      'refundability': 'NotRefundable',
      'journeys': [
        {
          'id': 'journey-abc',
          'origin': 'CAI',
          'destination': 'RUH',
          'numberOfStops': 0,
          'segment': [
            {
              'id': 'segment-abc',
              'origin': 'CAI',
              'destination': 'RUH',
              'departureDateTime': '2026-09-15T10:50:00+03:00',
              'arrivalDateTime': '2026-09-15T13:35:00+03:00',
              'departureTerminal': '3',
              'arrivalTerminal': '1',
              'flightTimeInMinutes': 165,
              'operatingCarrierCode': 'XY',
              'operatingCarrierName': 'Flight Operations Services',
              'operatingCarrierLogo': 'https://pics.avs.io/200/200/XY.png',
              'operatingFlightNumber': '264',
              'marketingCarrierCode': 'XY',
              'marketingFlightNumber': '264',
              'equipment': '320',
            },
          ],
        },
      ],
      'totalAmount': 7601,
      'taxesAmount': 3141.88,
      'baseAmount': 4459.12,
      'discountAmount': 0,
      'beforeDiscountAmount': 7601,
      'serviceChargeAmount': 0,
      'currency': 'EGP',
      'departureDate': '2026-09-15T10:50:00+03:00',
      'arrivalDate': '2026-09-15T13:35:00+03:00',
      'priceClasses': [
        {
          'classId': 'class-1',
          'priceClassName': 'Economy Basic',
          'fareType': 'PrivateFare',
          'rulesAndPenalties': [
            'Classification: CarryOn, Inclusion: Included, GroupCode: BG',
            'Change BeforeDeparture: EGP 3355',
          ],
        },
      ],
    },
  ],
};

const flightSearchEmptyEnvelope = {
  'status': 200,
  'message': 'Flight search results',
  'errors': <String, dynamic>{},
  'data': <Map<String, dynamic>>[],
};

/// Demo backend shape when a search finds nothing — HTTP 400, not an empty
/// 200 list. Treated as "no offers" by the client, not as a load failure.
const flightSearchNoOffersEnvelope = {
  'status': 400,
  'message': 'No available offers !',
  'errors': <String, dynamic>{},
  'data': <String, dynamic>{},
};
