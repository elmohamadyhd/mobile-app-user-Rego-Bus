import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:safaria/l10n/app_localizations.dart';

/// Strips the time component from [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Localized label for the home search date row.
String formatHomeSearchDate(
  DateTime date,
  AppLocalizations l10n,
  String localeName,
) {
  final day = dateOnly(date);
  final today = dateOnly(DateTime.now());
  if (isSameDay(day, today)) {
    final shortDate = DateFormat.MMMd(localeName).format(day);
    return l10n.homeSearchDateToday(shortDate);
  }
  return DateFormat.yMMMd(localeName).format(day);
}

/// Short date for compact search date cells (e.g. "2 Jul").
String formatSearchDateCell(DateTime date, String localeName) =>
    DateFormat.MMMd(localeName).format(dateOnly(date));

/// Compact date + time for private-car search cells (e.g. "2 Jul · 10:30 PM").
String formatSearchDateTimeCell(DateTime dateTime, String localeName) {
  final date = formatSearchDateCell(dateTime, localeName);
  final time = DateFormat.jm(localeName).format(dateTime);
  return '$date · $time';
}

/// Merges a calendar [date] with [time] into a local [DateTime].
DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  final day = dateOnly(date);
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// Next 30-minute slot from [now], or [now] if already on a 30-minute boundary.
TimeOfDay nextThirtyMinuteSlot([DateTime? now]) {
  final current = now ?? DateTime.now();
  final minutes = current.minute;
  final remainder = minutes % 30;
  final addMinutes = remainder == 0 ? 0 : 30 - remainder;
  final bumped = current.add(Duration(minutes: addMinutes));
  return TimeOfDay(hour: bumped.hour, minute: bumped.minute);
}

/// Default pickup time: next 30-minute slot today, otherwise 09:00.
TimeOfDay defaultDepartTimeForDate(DateTime date) {
  if (isSameDay(dateOnly(date), dateOnly(DateTime.now()))) {
    return nextThirtyMinuteSlot();
  }
  return const TimeOfDay(hour: 9, minute: 0);
}

/// Bumps [time] forward until [combineDateAndTime(date, time)] is not before [now].
TimeOfDay bumpTimeIfPast(DateTime date, TimeOfDay time, [DateTime? now]) {
  final reference = now ?? DateTime.now();
  final candidate = combineDateAndTime(date, time);
  if (!candidate.isBefore(reference)) return time;

  if (isSameDay(dateOnly(date), dateOnly(reference))) {
    return nextThirtyMinuteSlot(reference);
  }
  return const TimeOfDay(hour: 9, minute: 0);
}

/// ISO `yyyy-MM-dd` for API / booking state.
String toIsoDate(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(dateOnly(date));

/// Parses ISO `yyyy-MM-dd`; returns date-only or null on failure.
DateTime? parseIsoDate(String value) {
  try {
    final parsed = DateTime.parse(value);
    return dateOnly(parsed);
  } on FormatException {
    return null;
  }
}
