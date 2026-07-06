import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/utils/phone_number_formatter.dart';

void main() {
  group('formatNationalPhone', () {
    const egypt = [3, 3, 4];
    const gulfNine = [2, 3, 4];
    const gulfEight = [4, 4];

    test('formats Egypt 10 digits as 3-3-4', () {
      expect(formatNationalPhone('1012345678', egypt), '101 234 5678');
    });

    test('formats Saudi 9 digits as 2-3-4', () {
      expect(formatNationalPhone('501234567', gulfNine), '50 123 4567');
    });

    test('formats UAE 9 digits as 2-3-4', () {
      expect(formatNationalPhone('501234567', gulfNine), '50 123 4567');
    });

    test('formats Kuwait 8 digits as 4-4', () {
      expect(formatNationalPhone('12345678', gulfEight), '1234 5678');
    });

    test('formats Qatar 8 digits as 4-4', () {
      expect(formatNationalPhone('12345678', gulfEight), '1234 5678');
    });

    test('formats partial input while typing', () {
      expect(formatNationalPhone('101', egypt), '101');
      expect(formatNationalPhone('1012', egypt), '101 2');
      expect(formatNationalPhone('50', gulfNine), '50');
      expect(formatNationalPhone('123', gulfEight), '123');
    });

    test('truncates at max national length', () {
      expect(
        formatNationalPhone('101234567890', egypt),
        '101 234 5678',
      );
      expect(
        formatNationalPhone('50123456789', gulfNine),
        '50 123 4567',
      );
      expect(
        formatNationalPhone('123456789', gulfEight),
        '1234 5678',
      );
    });

    test('strips non-digits before formatting', () {
      expect(formatNationalPhone('10 1234-5678', egypt), '101 234 5678');
    });

    test('reflows digits when country pattern changes', () {
      const egyptDigits = '1012345678';
      expect(formatNationalPhone(egyptDigits, egypt), '101 234 5678');

      final truncatedForKuwait = egyptDigits.substring(0, 8);
      expect(
        formatNationalPhone(truncatedForKuwait, gulfEight),
        '1012 3456',
      );
    });

    test('returns empty string for empty input', () {
      expect(formatNationalPhone('', egypt), '');
      expect(formatNationalPhone('   ', egypt), '');
    });
  });

  group('maxNationalDigits', () {
    test('sums group sizes', () {
      expect(maxNationalDigits([3, 3, 4]), 10);
      expect(maxNationalDigits([2, 3, 4]), 9);
      expect(maxNationalDigits([4, 4]), 8);
    });
  });

  group('NationalPhoneInputFormatter', () {
    late NationalPhoneInputFormatter formatter;

    setUp(() {
      formatter = NationalPhoneInputFormatter(groupSizes: [3, 3, 4]);
    });

    test('formats digits on edit', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '1012345678',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );

      expect(result.text, '101 234 5678');
      expect(result.selection.baseOffset, 12);
    });
  });
}
