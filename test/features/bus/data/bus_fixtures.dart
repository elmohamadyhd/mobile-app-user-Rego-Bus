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

/// Real `POST /buses/create-ticket` response. The order is created in a
/// `pending` state, held ~15 min for payment. Key URL fields:
///   • `payment_data.invoice_url` → gateway hosted checkout (load in WebView)
///   • `payment_url`              → our backend `/pay` endpoint (fallback only)
///   • `invoice_url` (top level)  → the e-ticket PDF download
const createTicketEnvelope = {
  'status': 200,
  'message': 'order created',
  'errors': <String, dynamic>{},
  'data': {
    'number': '000001466',
    'id': 1466,
    'trip_id': '145658',
    'gateway_order_id': '5061990',
    'company_data': {'name': 'SuperJet', 'avatar': '', 'bus_image': '', 'pin': ''},
    'status': 'Pending',
    'status_code': 'pending',
    'gateway_id': 'SuperJet',
    'company_name': 'SuperJet',
    'category': 'VIP',
    'can_be_cancel': true,
    'trip_type': 'Buses',
    'is_confirmed': 0,
    'payment_data': {
      'status': 'Pending',
      'status_code': 'pending',
      'invoice_id': 6952058,
      'gateway': 'Myfatoorah',
      'invoice_url':
          'https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8',
      'data': {'notes': ''},
    },
    'invoice_url':
        'https://portal.wdenytravel.com/orders/1466/invoice/download',
    'tickets': [
      {'id': 2066, 'seat_number': '14', 'price': '225.00'},
    ],
    'date': '2026-07-30',
    'date_time': '2026-07-30 04:30 AM',
    'payment_url': 'https://portal.wdenytravel.com/api/v1/buses/orders/1466/pay',
    'cancel_url':
        'https://portal.wdenytravel.com/api/v1/buses/orders/1466/cancel',
    'total': 'EGP 240.75',
    'currency': 'EGP',
  },
};
