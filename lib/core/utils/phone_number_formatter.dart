import 'package:flutter/services.dart';

/// Egypt dial code — national numbers never keep a leading trunk `0`
/// when the country code is already selected (`+2010…`, not `+20010…`).
const kEgyptDial = '20';

/// Max national digits allowed for the given [groupSizes].
int maxNationalDigits(List<int> groupSizes) =>
    groupSizes.fold<int>(0, (sum, size) => sum + size);

/// Drops Egypt's national trunk prefix `0` when [dial] is [kEgyptDial].
String stripTrunkPrefix(String digits, {String? dial}) {
  if (dial != kEgyptDial) return digits;
  var result = digits;
  while (result.startsWith('0')) {
    result = result.substring(1);
  }
  return result;
}

/// Strips non-digits, truncates to the national max, and inserts group spaces.
///
/// When [dial] is Egypt (`20`), a leading trunk `0` is removed so users who
/// type `01x…` still get a valid `+201x…` national number.
String formatNationalPhone(
  String input,
  List<int> groupSizes, {
  String? dial,
}) {
  final rawDigits = input.replaceAll(RegExp(r'\D'), '');
  final digits = stripTrunkPrefix(rawDigits, dial: dial);
  final maxDigits = maxNationalDigits(groupSizes);
  final truncated =
      digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;

  if (truncated.isEmpty) return '';

  final buffer = StringBuffer();
  var offset = 0;
  for (final size in groupSizes) {
    if (offset >= truncated.length) break;
    if (buffer.isNotEmpty) buffer.write(' ');
    final end = offset + size;
    buffer.write(
      truncated.substring(offset, end.clamp(0, truncated.length)),
    );
    offset = end;
  }
  return buffer.toString();
}

/// Formats national phone digits as the user types, per-country grouping.
class NationalPhoneInputFormatter extends TextInputFormatter {
  NationalPhoneInputFormatter({
    required this.groupSizes,
    this.dial,
  });

  final List<int> groupSizes;
  final String? dial;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted =
        formatNationalPhone(newValue.text, groupSizes, dial: dial);

    // Digits before the cursor, after the same trunk-0 strip as the text.
    final index = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBefore = stripTrunkPrefix(
      newValue.text.substring(0, index).replaceAll(RegExp(r'\D'), ''),
      dial: dial,
    );
    final selectionIndex =
        _cursorIndexForDigitOffset(formatted, digitsBefore.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

  int _cursorIndexForDigitOffset(String formatted, int digitOffset) {
    if (digitOffset <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        seen++;
        if (seen >= digitOffset) return i + 1;
      }
    }
    return formatted.length;
  }
}
