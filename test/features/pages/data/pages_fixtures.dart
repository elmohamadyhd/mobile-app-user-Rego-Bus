const listEnvelope = {
  'status': 200,
  'message': 'Pages',
  'errors': {},
  'data': [
    {
      'id': 2,
      'title': 'Privacy And Policy',
      'slug': 'privacy-and-policy',
      'status': 1,
    },
    {
      'id': 1,
      'title': 'Terms and Conditions',
      'slug': 'terms-and-conditions',
      'status': 1,
    },
  ],
};

const detailEnvelope = {
  'status': 200,
  'message': 'Page details',
  'errors': {},
  'data': {
    'id': 1,
    'slug': 'terms-and-conditions',
    'title': 'Terms and Conditions',
    'content': '<p>Terms body</p>',
    'status': 1,
  },
};

const inactiveDetailEnvelope = {
  'status': 200,
  'message': 'Page details',
  'errors': {},
  'data': {
    'id': 1,
    'slug': 'terms-and-conditions',
    'title': 'Terms and Conditions',
    'content': '<p>Terms body</p>',
    'status': 0,
  },
};
