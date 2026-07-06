import 'package:flutter/services.dart';

/// Max national digits allowed for the given [groupSizes].
int maxNationalDigits(List<int> groupSizes) =>
    groupSizes.fold<int>(0, (sum, size) => sum + size);

/// Strips non-digits, truncates to the national max, and inserts group spaces.
String formatNationalPhone(String input, List<int> groupSizes) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
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
  NationalPhoneInputFormatter({required this.groupSizes});

  final List<int> groupSizes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatNationalPhone(digits, groupSizes);

    final oldDigitOffset =
        _digitOffsetBefore(newValue.text, newValue.selection);
    final selectionIndex =
        _cursorIndexForDigitOffset(formatted, oldDigitOffset);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

  int _digitOffsetBefore(String text, TextSelection selection) {
    final index = selection.baseOffset.clamp(0, text.length);
    return text.substring(0, index).replaceAll(RegExp(r'\D'), '').length;
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
