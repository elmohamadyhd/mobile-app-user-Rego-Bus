/// Captured from a live GET /flights/{offer_id}/bundles (200), using the
/// offer id returned by confirm — not the one from search.
///
/// Round-trip CAI→RUH (2026-08-29 / 2026-09-05), 1 ADT. Confirm minted a new
/// offer id (A ≠ B). Calling bundles with A returned
/// `400 "…not valid or expired"`; calling with B returned this payload.
/// Trimmed to two journeys and two bundles each.
const bundlesEnvelope = {
  'status': 200,
  'message': 'Available bundles',
  'errors': <String, dynamic>{},
  'data': [
    {
      'offer_journey_id':
          'Rmx5YWRlYWwjRUdZI1JqTl9JRFl4Tm40Z2ZuNURRVWxfTURndk1qa3ZNakF5TmlBd01qb3pOWDVTVlVoX01EZ3ZNamt2TWpBeU5pQXdOVG95TUg1Xw==',
      'bundles': [
        {
          'bundle_code': 'FCAI',
          'bundle_name': 'Fly',
          'bundle_prices': {
            'bundle_references': '0',
            'passenger_type_code': 'ADT',
            'total_amount': 0,
            'taxes_amount': 0,
            'fee_mount': 0,
            'currency': 'EGP',
          },
          'included_services': [
            'Airport check-in',
            'Cairo Snack & Beverage',
            '15kg baggage allowance',
            'No Alfursan Miles Fly bundle',
          ],
        },
        {
          'bundle_code': 'PCAI',
          'bundle_name': 'Fly+',
          'bundle_prices': {
            'bundle_references': '1',
            'passenger_type_code': 'ADT',
            'total_amount': 2085,
            'taxes_amount': 0,
            'fee_mount': 2085,
            'currency': 'EGP',
          },
          'included_services': [
            'Airport check-in',
            'Al Fursan Miles',
            'Cairo Snack & Beverage',
            '30kg baggage allowance',
          ],
        },
      ],
    },
    {
      'offer_journey_id':
          'Rmx5YWRlYWwjRUdZI1JqTl9JRFl4TTM0Z2ZuNVNWVWhfTURrdk1EVXZNakF5TmlBd09Eb3pNSDVEUVVsX01Ea3ZNRFV2TWpBeU5pQXhNVG94TUg1Xw==',
      'bundles': [
        {
          'bundle_code': 'FCAI',
          'bundle_name': 'Fly',
          'bundle_prices': {
            'bundle_references': '0',
            'passenger_type_code': 'ADT',
            'total_amount': 0,
            'taxes_amount': 0,
            'fee_mount': 0,
            'currency': 'EGP',
          },
          'included_services': [
            'Airport check-in',
            'Cairo Snack & Beverage',
            '15kg baggage allowance',
            'No Alfursan Miles Fly bundle',
          ],
        },
        {
          'bundle_code': 'PCAI',
          'bundle_name': 'Fly+',
          'bundle_prices': {
            'bundle_references': '1',
            'passenger_type_code': 'ADT',
            'total_amount': 2085,
            'taxes_amount': 0,
            'fee_mount': 2085,
            'currency': 'EGP',
          },
          'included_services': [
            'Airport check-in',
            'Al Fursan Miles',
            'Cairo Snack & Beverage',
            '30kg baggage allowance',
          ],
        },
      ],
    },
  ],
};
