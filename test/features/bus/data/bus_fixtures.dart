const tripsSearchEnvelope = {
  'status': 200,
  'message': 'Trips list',
  'errors': {},
  'data': [
    {
      'id': 290545,
      'gateway_id': 'Tazcara',
      'company': 'النورس للنقل البري',
      'company_data': {
        'name': 'النورس للنقل البري',
        'avatar': '',
        'bus_image': '',
        'pin': '',
      },
      'category': 'VIP',
      'date': '2025-02-10',
      'time': '07:00 am',
      'date_time': '2025-02-10 07:00',
      'stations_from': [
        {
          'id': 985052,
          'city_id': 1,
          'city_name': 'القاهره',
          'arrival_at': '2025-02-10 07:00:00',
          'name': 'القللي',
          'final_price': 0,
          'original_price': 0,
        },
      ],
      'stations_to': [
        {
          'id': 985053,
          'city_id': 2,
          'city_name': 'الاسكندريه',
          'arrival_at': '2025-02-10 10:00:00',
          'name': 'محرم بك',
          'final_price': 148.5,
          'original_price': 150,
        },
      ],
      'price_start_with': 148.5,
      'available_seats': 6,
    },
  ],
  'pagination': {
    'total': 1,
    'lastPage': 1,
    'perPage': 10,
    'currentPage': 1,
    'nextPageUrl': null,
    'previousPageUrl': null,
  },
};

const tripByIdEmptyStationsEnvelope = {
  'status': 200,
  'message': 'Trip details',
  'errors': {},
  'data': {
    'id': 236510,
    'gateway_id': 'BlueBus',
    'company': 'بلو باص',
    'category': 'first8',
    'date_time': '2026-07-10 00:01',
    'stations_from': [],
    'stations_to': [],
    'price_start_with': 26.2,
    'available_seats': 0,
  },
};
