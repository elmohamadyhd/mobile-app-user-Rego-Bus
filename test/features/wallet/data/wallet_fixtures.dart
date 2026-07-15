const walletEnvelope = {
  'status': 200,
  'message': 'Wallet',
  'errors': {},
  'data': [
    {
      'id': 79,
      'balance': '25.00',
      'transactions': [
        {
          'id': 86,
          'description': 'تم إضافة 25 جنيه لمحفظتك ترحيبًا بك معنا. ',
          'type': 'deposit',
          'amount': '25.00',
        },
      ],
    },
  ],
};

const walletEmptyDataEnvelope = {
  'status': 200,
  'message': 'Wallet',
  'errors': {},
  'data': <Map<String, dynamic>>[],
};

const walletErrorEnvelope = {
  'status': 401,
  'message': 'Unauthenticated.',
  'errors': {},
  'data': <Map<String, dynamic>>[],
};

const chargeEnvelope = {
  'status': 200,
  'message': 'Payment link',
  'errors': {},
  'data': {
    'link': 'https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8',
  },
};

const chargeMissingLinkEnvelope = {
  'status': 200,
  'message': 'Payment link',
  'errors': {},
  'data': <String, dynamic>{},
};
