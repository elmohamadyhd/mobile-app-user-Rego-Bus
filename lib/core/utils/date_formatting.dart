import 'package:intl/intl.dart';

import 'package:rego/l10n/app_localizations.dart';

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
