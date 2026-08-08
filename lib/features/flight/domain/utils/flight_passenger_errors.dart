/// Splits `ApiException.errors` into per-passenger field errors.
///
/// The endpoint keys validation failures by position —
/// `passengers.1.documentNumber`. On a screen holding up to nine travellers,
/// a single banner saying "check your details" tells the rider nothing about
/// who to fix, so the index is parsed and the message pinned to that row.
///
/// Keys that are not passenger-indexed belong to the booking as a whole and
/// are left to the caller's general error handling.
Map<int, Map<String, String>> flightPassengerErrorsByIndex(
  Map<String, List<String>>? errors,
) {
  if (errors == null) return const {};
  final byIndex = <int, Map<String, String>>{};

  for (final entry in errors.entries) {
    final parts = entry.key.split('.');
    if (parts.length < 3 || parts.first != 'passengers') continue;
    final index = int.tryParse(parts[1]);
    if (index == null) continue;
    if (entry.value.isEmpty) continue;
    final field = parts.sublist(2).join('.');
    (byIndex[index] ??= <String, String>{})[field] = entry.value.first;
  }

  return byIndex;
}
