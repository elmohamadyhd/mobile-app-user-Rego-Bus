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
    'company_data': {
      'name': 'SuperJet',
      'avatar': '',
      'bus_image': '',
      'pin': ''
    },
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
    'payment_url': 'https://demo.safaria.travel/api/v1/buses/orders/1466/pay',
    'cancel_url': 'https://demo.safaria.travel/api/v1/buses/orders/1466/cancel',
    'total': 'EGP 240.75',
    'currency': 'EGP',
  },
};

/// Real `GET /profile/buses/orders` response (trimmed to mapped fields).
/// See docs/wadeny-apis.md → Orders > Buses. Second entry has no
/// `payment_data` at all, to exercise a confirmed order with no checkout URL.
const busOrdersEnvelope = {
  'status': 200,
  'message': 'Bus orders',
  'errors': <String, dynamic>{},
  'data': [
    {
      'number': '000001475',
      'id': 1475,
      'company_data': {
        'name': 'SuperJet',
        'avatar': '',
        'bus_image': '',
        'pin': '',
      },
      'status': 'Pending',
      'status_code': 'pending',
      'company_name': 'SuperJet',
      'category': 'Five stars',
      'can_be_cancel': true,
      'is_confirmed': 0,
      'payment_data': {
        'status': 'Pending',
        'status_code': 'pending',
        'invoice_id': 6956732,
        'gateway': 'Myfatoorah',
        'invoice_url': 'https://demo.MyFatoorah.com/KWT/ia/010726954',
        'data': {'notes': ''},
      },
      'invoice_url': 'https://portal.wdenytravel.com/orders/1475/invoice',
      'station_from': {
        'id': 1,
        'name': 'Cairo Main Station',
      },
      'station_to': {
        'id': 5,
        'name': 'Alexandria Terminal',
      },
      'tickets': [
        {'id': 2076, 'seat_number': '1', 'price': '205.00'},
      ],
      'date': '2026-07-30',
      'date_time': '2026-07-30 08:45 AM',
      'cancel_url':
          'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
      'total': 'EGP 219.35',
      'currency': 'EGP',
    },
    {
      'number': '000001470',
      'id': 1470,
      'company_data': {
        'name': 'SuperJet',
        'avatar': '',
        'bus_image': '',
        'pin': '',
      },
      'status': 'Confirmed',
      'status_code': 'confirmed',
      'company_name': 'SuperJet',
      'category': 'VIP',
      'can_be_cancel': false,
      'is_confirmed': 1,
      'invoice_url': 'https://portal.wdenytravel.com/orders/1470/invoice',
      'tickets': [
        {'id': 2070, 'seat_number': '2', 'price': '225.00'},
      ],
      'date': '2026-07-30',
      'date_time': '2026-07-30 04:30 AM',
      'total': 'EGP 240.75',
      'currency': 'EGP',
    },
  ],
  'pagination': {
    'total': 2,
    'lastPage': 1,
    'perPage': 15,
    'currentPage': 1,
    'nextPageUrl': null,
    'previousPageUrl': null,
  },
};

/// Real `GET /profile/buses/orders/:id` response for order 1475 — see
/// docs/wadeny-apis.md → Orders > Buses > Show. Field-for-field identical to
/// the matching element in `busOrdersEnvelope.data[]`, plus the fare
/// breakdown / payment / identifier fields the list fixture above omits.
const busOrderShowEnvelope = {
  'status': 200,
  'message': 'Bus order',
  'errors': <String, dynamic>{},
  'data': {
    'number': '000001475',
    'id': 1475,
    'trip_id': '145261',
    'gateway_order_id': '5077099',
    'parent_order_id': null,
    'company_data': {
      'name': 'SuperJet',
      'avatar': '',
      'bus_image': '',
      'pin': '',
    },
    'status': 'Pending',
    'status_code': 'pending',
    'gateway_id': 'SuperJet',
    'company_name': 'SuperJet',
    'category': 'Five stars',
    'can_be_cancel': true,
    'trip_type': 'Buses',
    'is_confirmed': 0,
    'review': null,
    'can_review': false,
    'payment_data': {
      'status': 'Pending',
      'status_code': 'pending',
      'invoice_id': 6956732,
      'gateway': 'Myfatoorah',
      'invoice_url': 'https://demo.MyFatoorah.com/KWT/ia/010726954',
      'data': {'notes': ''},
    },
    'invoice_url': 'https://portal.wdenytravel.com/orders/1475/invoice',
    'station_from': null,
    'station_to': null,
    'tickets': [
      {'id': 2076, 'seat_number': '1', 'price': '205.00'},
    ],
    'date': '2026-07-30',
    'date_time': '2026-07-30 08:45 AM',
    'payment_url': 'https://demo.safaria.travel/api/v1/buses/orders/1475/pay',
    'cancel_url': 'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
    'original_tickets_totals': 'EGP 205.00',
    'discount': 'EGP 0.00',
    'wallet_discount': 'EGP 0.00',
    'tickets_totals_after_discount': 'EGP 205.00',
    'payment_fees': 'EGP 14.35',
    'total': 'EGP 219.35',
    'currency': 'EGP',
  },
};

/// Real 404 for an unknown/foreign order id — docs/wadeny-apis.md → Orders >
/// Buses > Show. In production Dio throws before the mapper ever sees this
/// body (see `bus_api.dart` — no `validateStatus` override, so a real HTTP
/// 404 raises `DioException` first); this fixture exercises `orderFromEnvelope`
/// / `ensureSuccess`'s own defensive contract directly.
const busOrderNotFoundEnvelope = {
  'status': 404,
  'message': 'Bus order not found',
  'errors': <String, dynamic>{},
  'data': <String, dynamic>{},
};
