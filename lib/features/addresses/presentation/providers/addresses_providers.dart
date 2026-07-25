import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/addresses/data/addresses_api.dart';
import 'package:safaria/features/addresses/data/addresses_repository_impl.dart';
import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/repositories/addresses_repository.dart';

final addressesApiProvider =
    Provider<AddressesApi>((ref) => AddressesApi(ref.watch(dioProvider)));

final addressesRepositoryProvider = Provider<AddressesRepository>(
  (ref) => AddressesRepositoryImpl(ref.watch(addressesApiProvider)),
);

class AddressesNotifier extends AsyncNotifier<AddressPage> {
  @override
  Future<AddressPage> build() =>
      ref.read(addressesRepositoryProvider).list(page: 1);

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(addressesRepositoryProvider).list(page: 1),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNextPage) return;
    final nextPage = current.currentPage + 1;
    final next = await ref.read(addressesRepositoryProvider).list(page: nextPage);
    state = AsyncData(current.append(next));
  }

  Future<void> delete(int id) async {
    await ref.read(addressesRepositoryProvider).delete(id);
    await refresh();
  }
}

final addressesProvider =
    AsyncNotifierProvider<AddressesNotifier, AddressPage>(AddressesNotifier.new);
