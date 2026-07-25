import 'package:safaria/features/addresses/domain/entities/saved_address.dart';

final class AddressPage {
  const AddressPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<SavedAddress> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasNextPage => currentPage < lastPage;

  AddressPage append(AddressPage next) => AddressPage(
        items: [...items, ...next.items],
        currentPage: next.currentPage,
        lastPage: next.lastPage,
        total: next.total,
      );
}
