final class CarCompany {
  const CarCompany({
    required this.id,
    required this.name,
    required this.refundability,
    this.refundPolicy,
    this.logoUrl,
  });

  final int id;
  final String name;
  final bool refundability;
  final String? refundPolicy;
  final String? logoUrl;
}

final class CarVehicle {
  const CarVehicle({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.seatsNumber,
    this.model,
    this.year,
    this.bigBagsCount,
    this.smallBagsCount,
    this.gearType,
    this.featuredUrl,
  });

  final int id;
  final String name;
  final String categoryName;
  final int seatsNumber;
  final String? model;
  final int? year;
  final int? bigBagsCount;
  final int? smallBagsCount;
  final String? gearType;
  final String? featuredUrl;
}

final class CarNamedLocation {
  const CarNamedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
}

final class CarTripQuote {
  const CarTripQuote({
    required this.id,
    required this.rounded,
    required this.goPrice,
    required this.roundPrice,
    required this.currency,
    required this.company,
    required this.fromLocation,
    required this.toLocation,
    required this.vehicle,
  });

  final int id;
  final bool rounded;
  final double goPrice;
  final double roundPrice;
  final String currency;
  final CarCompany company;
  final CarNamedLocation fromLocation;
  final CarNamedLocation toLocation;
  final CarVehicle vehicle;

  double priceFor({required bool rounded}) => rounded ? roundPrice : goPrice;
}
