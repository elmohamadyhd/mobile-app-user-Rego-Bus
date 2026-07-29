import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/notifications/data/notifications_dto_mapper.dart';

void main() {
  test('pageFromEnvelope maps unread and read items', () {
    final page = NotificationsDtoMapper.pageFromEnvelope({
      'data': [
        {
          'id': 'a',
          'title': 'T1',
          'description': 'D1',
          'created_date': '2026-07-02 12:48:02',
          'formatted_date': '2026-07-02 12:48 pm',
          'data': <String, dynamic>{},
          'read_at': null,
        },
        {
          'id': 'b',
          'title': 'T2',
          'description': 'D2',
          'created_date': '2026-07-02 12:46:05',
          'formatted_date': '2026-07-02 12:46 pm',
          'data': {'x': 1},
          'read_at': '2026-07-02T10:56:45.000000Z',
        },
      ],
      'pagination': {
        'total': 2,
        'lastPage': 1,
        'perPage': 15,
        'currentPage': 1,
      },
    });

    expect(page.items.length, 2);
    expect(page.items[0].isUnread, isTrue);
    expect(page.items[1].isUnread, isFalse);
    expect(page.items[1].data['x'], 1);
    expect(page.currentPage, 1);
    expect(page.hasNextPage, isFalse);
  });

  test('append merges pages and advances cursor', () {
    final first = NotificationsDtoMapper.pageFromEnvelope({
      'data': [
        {
          'id': 'a',
          'title': 'T1',
          'description': 'D1',
          'created_date': '1',
          'formatted_date': '1',
          'data': <String, dynamic>{},
          'read_at': null,
        },
      ],
      'pagination': {
        'total': 2,
        'lastPage': 2,
        'currentPage': 1,
      },
    });
    final second = NotificationsDtoMapper.pageFromEnvelope({
      'data': [
        {
          'id': 'b',
          'title': 'T2',
          'description': 'D2',
          'created_date': '2',
          'formatted_date': '2',
          'data': <String, dynamic>{},
          'read_at': null,
        },
      ],
      'pagination': {
        'total': 2,
        'lastPage': 2,
        'currentPage': 2,
      },
    });

    final merged = first.append(second);
    expect(merged.items.map((n) => n.id), ['a', 'b']);
    expect(merged.currentPage, 2);
    expect(merged.hasNextPage, isFalse);
  });
}
