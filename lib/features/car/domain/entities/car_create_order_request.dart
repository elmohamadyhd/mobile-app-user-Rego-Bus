final class CarCreateOrderRequest {
  const CarCreateOrderRequest({
    required this.tripId,
    required this.rounded,
    required this.departureLatitude,
    required this.departureLongitude,
    required this.departureDate,
    required this.departureName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationDate,
    required this.destinationName,
  });

  final int tripId;
  final bool rounded;
  final String departureLatitude;
  final String departureLongitude;
  final String departureDate;
  final String departureName;
  final String destinationLatitude;
  final String destinationLongitude;
  final String destinationDate;
  final String destinationName;
}
