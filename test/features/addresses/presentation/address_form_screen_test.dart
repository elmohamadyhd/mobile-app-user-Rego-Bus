import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/presentation/address_form_screen.dart';
import 'package:safaria/features/addresses/presentation/providers/addresses_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _sampleAddress = SavedAddress(
  id: 1,
  name: 'Home',
  mapLocation: MapLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    addressName: '123 Nile Street, Cairo',
  ),
  phone: '1554052685',
  notes: 'Ring twice',
);

class _FakeAddressesNotifier extends AddressesNotifier {
  _FakeAddressesNotifier(this._page);

  final AddressPage _page;

  @override
  Future<AddressPage> build() async => _page;
}

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    int? addressId,
    AddressPage? page,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (page != null)
            addressesProvider.overrideWith(
              () => _FakeAddressesNotifier(page),
            ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AddressFormScreen(addressId: addressId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('create mode shows addressFormCreateTitle', (tester) async {
    await pumpForm(tester);

    expect(find.text('New address'), findsOneWidget);
    expect(find.text('Edit address'), findsNothing);
  });

  testWidgets('edit mode with overridden addressesProvider shows pre-filled name',
      (tester) async {
    await pumpForm(
      tester,
      addressId: 1,
      page: const AddressPage(
        items: [_sampleAddress],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );

    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('create mode hides delete button', (tester) async {
    await pumpForm(tester);
    expect(find.text('Delete address'), findsNothing);
  });

  testWidgets('edit mode shows delete button', (tester) async {
    await pumpForm(
      tester,
      addressId: 1,
      page: const AddressPage(
        items: [_sampleAddress],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );
    expect(find.text('Delete address'), findsOneWidget);
  });
}
