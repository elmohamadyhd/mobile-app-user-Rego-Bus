import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/l10n/app_localizations.dart';

String featureLabel(AppLocalizations l10n, BusFeature feature) {
  switch (feature.id.toLowerCase()) {
    case 'wifi':
      return l10n.amenityWifi;
    case 'ac':
      return l10n.amenityAC;
    case 'sockets':
    case 'plug':
    case 'power':
      return l10n.amenitySockets;
    case 'wc':
      return l10n.amenityWc;
    case 'dvd':
      return l10n.amenityDvd;
    case 'gps':
      return l10n.amenityGps;
    default:
      return feature.name;
  }
}
