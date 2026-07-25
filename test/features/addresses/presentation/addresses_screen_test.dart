import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/presentation/addresses_screen.dart';
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
);

class _FakeAddressesNotifier extends AddressesNotifier {
  _FakeAddressesNotifier(this._page);

  final AddressPage _page;

  @override
  Future<AddressPage> build() async => _page;
}

void main() {
  Future<void> pumpAddresses(
    WidgetTester tester,
    AddressPage page,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesProvider.overrideWith(
            () => _FakeAddressesNotifier(page),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows title and address name when list has items',
      (tester) async {
    await pumpAddresses(
      tester,
      const AddressPage(
        items: [_sampleAddress],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );

    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('123 Nile Street, Cairo'), findsOneWidget);
  });

  testWidgets('shows empty state when list is empty', (tester) async {
    await pumpAddresses(
      tester,
      const AddressPage(
        items: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
      ),
    );

    expect(find.text('No saved addresses yet'), findsOneWidget);
  });
}
