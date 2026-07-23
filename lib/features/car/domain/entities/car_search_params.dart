import 'package:rego/features/car/domain/entities/car_place.dart';

final class CarSearchParams {
  const CarSearchParams({
    required this.from,
    required this.to,
    required this.rounded,
    required this.departDate,
    this.returnDate,
  });

  final CarPlace from;
  final CarPlace to;
  final bool rounded;
  final DateTime departDate;
  final DateTime? returnDate;
}
