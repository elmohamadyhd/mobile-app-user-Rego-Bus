final class CarCreateOrderRequest {
  const CarCreateOrderRequest({
    required this.tripId,
    required this.rounded,
    required this.departureLatitude,
    required this.departureLongitude,
    required this.departureDate,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationDate,
  });

  final int tripId;
  final bool rounded;
  final String departureLatitude;
  final String departureLongitude;
  final String departureDate;
  final String destinationLatitude;
  final String destinationLongitude;
  final String destinationDate;
}
