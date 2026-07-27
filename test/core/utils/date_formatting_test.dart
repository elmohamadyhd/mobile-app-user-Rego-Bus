import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:safaria/core/utils/date_formatting.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('combineDateAndTime merges date and time', () {
    final result = combineDateAndTime(
      DateTime(2026, 7, 28),
      const TimeOfDay(hour: 22, minute: 15),
    );

    expect(result.year, 2026);
    expect(result.month, 7);
    expect(result.day, 28);
    expect(result.hour, 22);
    expect(result.minute, 15);
  });

  test('nextThirtyMinuteSlot rounds up within the hour', () {
    final slot = nextThirtyMinuteSlot(DateTime(2026, 7, 28, 10, 7));
    expect(slot.hour, 10);
    expect(slot.minute, 30);
  });

  test('formatSearchDateTimeCell includes date and time', () {
    final label = formatSearchDateTimeCell(
      DateTime(2026, 7, 28, 22, 0),
      'en',
    );

    expect(label, contains('·'));
    expect(label.toLowerCase(), contains('10:00'));
  });
}
