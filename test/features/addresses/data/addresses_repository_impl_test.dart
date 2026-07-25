import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/addresses/data/addresses_api.dart';
import 'package:safaria/features/addresses/data/addresses_repository_impl.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';

import 'addresses_fixtures.dart';

class _FakeAddressesApi extends AddressesApi {
  _FakeAddressesApi({this.listBody, this.createBody}) : super(Dio());

  final dynamic listBody;
  final dynamic createBody;

  @override
  Future<dynamic> list({int page = 1}) async => listBody;

  @override
  Future<dynamic> create(Map<String, dynamic> body) async => createBody;
}

void main() {
  group('AddressesRepositoryImpl', () {
    test('list() returns one item with id 22', () async {
      final repo = AddressesRepositoryImpl(
        _FakeAddressesApi(listBody: listEnvelope),
      );

      final page = await repo.list();

      expect(page.items, hasLength(1));
      expect(page.items.first.id, 22);
      expect(page.items.first.name, 'Home');
    });

    test('create() returns id 23', () async {
      final repo = AddressesRepositoryImpl(
        _FakeAddressesApi(createBody: createEnvelope),
      );

      final address = await repo.create(
        name: 'Work',
        mapLocation: const MapLocation(
          latitude: 31.04,
          longitude: 31.37,
          addressName: 'Smart Village B12',
        ),
        phone: '1090510796',
      );

      expect(address.id, 23);
      expect(address.name, 'Work');
    });
  });
}
