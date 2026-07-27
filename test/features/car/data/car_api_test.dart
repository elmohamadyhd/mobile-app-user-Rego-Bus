import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/car/data/car_api.dart';

void main() {
  test('searchQuotes sends date and return_date with time', () async {
    Map<String, dynamic>? captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = Map<String, dynamic>.from(options.queryParameters);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'status': 200, 'data': []},
              ),
            );
          },
        ),
      );

    final api = CarApi(dio);
    await api.searchQuotes(
      fromLatitude: 30.03,
      fromLongitude: 31.26,
      toLatitude: 31.18,
      toLongitude: 29.89,
      rounded: true,
      departDate: DateTime(2026, 10, 10, 22, 10),
      returnDate: DateTime(2026, 10, 12, 22, 10),
    );

    expect(captured, isNotNull);
    final query = captured!;
    expect(query['date'], '2026-10-10 22:10');
    expect(query['return_date'], '2026-10-12 22:10');
    expect(query['rounded'], true);
  });
}
