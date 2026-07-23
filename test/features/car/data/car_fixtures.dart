/// Trimmed from docs/wadeny-apis.md → Private → Search (200).
const privateSearchEnvelope = {
  'status': 200,
  'message': 'Trips',
  'errors': <String, dynamic>{},
  'data': [
    {
      'id': 1,
      'rounded': true,
      'go_price': 69.87,
      'round_price': 104.81,
      'currency': 'SAR',
      'status': true,
      'currency_id': 1,
      'base_currency_id': 1,
      'exchange_rate': '1.00000000',
      'company': {
        'id': 1,
        'name': 'Sky Travel',
        'refundability': true,
        'refund_policy': 'Sky Travel',
        'logo_url':
            'https://demo.safaria.travel/storage/15/6a1f0a7b628ff_images-(1).jpeg',
        'logo_mime_type': 'image/jpeg',
      },
      'from_location': {
        'id': 1,
        'name': 'Cairo',
        'latitude': '30.0441028',
        'longitude': '31.2408498',
      },
      'to_location': {
        'id': 2,
        'name': 'Alexandria',
        'latitude': '31.2452475',
        'longitude': '29.9892346',
      },
      'vehicle': {
        'id': 1,
        'name': 'Hundai',
        'category_id': 1,
        'category_name': 'Sedan',
        'seats_number': 5,
        'model': 'Matrix',
        'year': 2010,
        'big_bags_count': 4,
        'small_bags_count': 1,
        'gear_type': 'automatic',
        'featured_url':
            'https://demo.safaria.travel/storage/16/6a1f0aecdea34_large.jpg',
        'featured_mime_type': 'image/jpeg',
      },
    },
  ],
};

const privateSearchEmptyEnvelope = {
  'status': 200,
  'message': 'Trips',
  'errors': <String, dynamic>{},
  'data': <dynamic>[],
};
