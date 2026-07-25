import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';

abstract final class AddressesDtoMapper {
  static AddressPage pageFromEnvelope(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final pagination =
        map['pagination'] as Map<String, dynamic>? ?? const {};
    return AddressPage(
      items: data.map(_addressFromMap).toList(growable: false),
      currentPage: _int(pagination['currentPage'], fallback: 1),
      lastPage: _int(pagination['lastPage'], fallback: 1),
      total: _int(pagination['total'], fallback: data.length),
    );
  }

  static SavedAddress addressFromEnvelope(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data = map['data'];
    if (data is Map<String, dynamic>) return _addressFromMap(data);
    throw const FormatException('Expected data object in address envelope');
  }

  static Map<String, dynamic> writeBody({
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
  }) =>
      {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'map_location': {
          'lat': mapLocation.latitude,
          'lng': mapLocation.longitude,
          'address_name': mapLocation.addressName,
        },
      };

  static SavedAddress _addressFromMap(Map<String, dynamic> json) {
    final loc = json['map_location'] as Map<String, dynamic>? ?? const {};
    return SavedAddress(
      id: _int(json['id']),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      notes: json['notes']?.toString(),
      whatsappShareLink: json['whatsapp_share_link']?.toString(),
      mapLocation: MapLocation(
        latitude: _double(loc['lat']),
        longitude: _double(loc['lng']),
        addressName: loc['address_name']?.toString() ?? '',
      ),
    );
  }

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
