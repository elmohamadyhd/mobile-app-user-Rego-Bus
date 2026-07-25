import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';

abstract interface class AddressesRepository {
  Future<AddressPage> list({int page = 1});

  Future<SavedAddress> create({
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
  });

  Future<SavedAddress> update({
    required int id,
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
  });

  Future<void> delete(int id);
}
