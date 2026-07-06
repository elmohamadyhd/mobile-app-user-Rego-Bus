import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/utils/device_token.dart';

void main() {
  final uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generateDeviceToken returns a 36-char UUID v4 string', () {
    final token = generateDeviceToken();
    expect(token.length, 36);
    expect(token, matches(uuidV4Pattern));
  });

  test('generateDeviceToken returns different values on successive calls', () {
    final first = generateDeviceToken();
    final second = generateDeviceToken();
    expect(first, isNot(equals(second)));
  });
}
