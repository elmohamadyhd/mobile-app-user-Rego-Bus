import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/addresses/data/addresses_api.dart';
import 'package:safaria/features/addresses/data/addresses_dto_mapper.dart';
import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/domain/repositories/addresses_repository.dart';

class AddressesRepositoryImpl implements AddressesRepository {
  AddressesRepositoryImpl(this._api);

  final AddressesApi _api;

  @override
  Future<AddressPage> list({int page = 1}) =>
      _guard(() async => AddressesDtoMapper.pageFromEnvelope(
            await _api.list(page: page),
          ));

  @override
  Future<SavedAddress> create({
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
  }) =>
      _guard(() async => AddressesDtoMapper.addressFromEnvelope(
            await _api.create(AddressesDtoMapper.writeBody(
              name: name,
              mapLocation: mapLocation,
              phone: phone,
              notes: notes,
            )),
          ));

  @override
  Future<SavedAddress> update({
    required int id,
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
  }) =>
      _guard(() async => AddressesDtoMapper.addressFromEnvelope(
            await _api.update(
              id,
              AddressesDtoMapper.writeBody(
                name: name,
                mapLocation: mapLocation,
                phone: phone,
                notes: notes,
              ),
            ),
          ));

  @override
  Future<void> delete(int id) => _guard(() => _api.delete(id));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
