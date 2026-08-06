import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_pagination.freezed.dart';

@freezed
abstract class FlightPagination with _$FlightPagination {
  const factory FlightPagination({
    required int total,
    required int lastPage,
    required int perPage,
    required int currentPage,
    String? nextPageUrl,
    String? previousPageUrl,
  }) = _FlightPagination;

  const FlightPagination._();

  static const empty = FlightPagination(
    total: 0,
    lastPage: 1,
    perPage: 0,
    currentPage: 1,
  );

  bool get hasNextPage => nextPageUrl != null;
}
