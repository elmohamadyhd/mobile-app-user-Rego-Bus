const listEnvelope = {
  'status': 200,
  'message': 'Customer addresses list',
  'errors': {},
  'data': [
    {
      'id': 22,
      'city': null,
      'name': 'Home',
      'phone': '1554052685',
      'notes': 'Ring twice',
      'whatsapp_share_link': 'https://example.com/wa',
      'map_location': {
        'lat': 24.2222,
        'lng': 46.5555,
        'address_name': '12 El Tahrir St',
      },
    },
  ],
  'pagination': {
    'total': 1,
    'lastPage': 1,
    'perPage': 15,
    'currentPage': 1,
    'nextPageUrl': null,
    'previousPageUrl': null,
  },
};

const createEnvelope = {
  'status': 200,
  'message': 'Created',
  'errors': {},
  'data': {
    'id': 23,
    'city': null,
    'name': 'Work',
    'phone': '1090510796',
    'notes': null,
    'whatsapp_share_link': 'https://example.com/wa2',
    'map_location': {
      'lat': 31.04,
      'lng': 31.37,
      'address_name': 'Smart Village B12',
    },
  },
};
