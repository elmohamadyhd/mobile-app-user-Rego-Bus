import 'package:go_router/go_router.dart';

import 'package:safaria/features/addresses/presentation/address_form_screen.dart';
import 'package:safaria/features/addresses/presentation/addresses_screen.dart';

abstract final class AddressesRoutes {
  static const list = '/profile/addresses';
  static const create = '/profile/addresses/new';
  static String edit(int id) => '/profile/addresses/$id/edit';
}

List<RouteBase> addressesRoutes() => [
      GoRoute(
        path: AddressesRoutes.list,
        builder: (_, __) => const AddressesScreen(),
      ),
      GoRoute(
        path: AddressesRoutes.create,
        builder: (_, __) => const AddressFormScreen(),
      ),
      GoRoute(
        path: '/profile/addresses/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddressFormScreen(addressId: id);
        },
      ),
    ];
