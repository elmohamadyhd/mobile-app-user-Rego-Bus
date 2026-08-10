import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/presentation/providers/addresses_providers.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/home/presentation/widgets/saved_addresses_strip.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _home = SavedAddress(
  id: 1,
  name: 'Home',
  mapLocation: MapLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    addressName: '123 Nile Street, Cairo',
  ),
);

const _work = SavedAddress(
  id: 2,
  name: 'Work',
  mapLocation: MapLocation(
    latitude: 30.06,
    longitude: 31.22,
    addressName: '456 Corniche, Cairo',
  ),
);

class _FakeAddressesNotifier extends AddressesNotifier {
  _FakeAddressesNotifier(this._page);

  final AddressPage _page;

  @override
  Future<AddressPage> build() async => _page;
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

AddressPage _page(List<SavedAddress> items) => AddressPage(
      items: items,
      currentPage: 1,
      lastPage: 1,
      total: items.length,
    );

Future<void> _pumpStrip(
  WidgetTester tester, {
  required bool visible,
  required bool isGuest,
  required AddressPage page,
  CarPlace? excludePlace,
  ValueChanged<CarPlace>? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        addressesProvider.overrideWith(() => _FakeAddressesNotifier(page)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SavedAddressesStrip(
            visible: visible,
            excludePlace: excludePlace,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing when not visible', (tester) async {
    await _pumpStrip(
      tester,
      visible: false,
      isGuest: false,
      page: _page([_home]),
    );
    expect(find.text('Saved addresses'), findsNothing);
  });

  testWidgets('renders nothing when guest', (tester) async {
    await _pumpStrip(
      tester,
      visible: true,
      isGuest: true,
      page: _page([_home]),
    );
    expect(find.text('Saved addresses'), findsNothing);
  });

  testWidgets('renders nothing when address list empty', (tester) async {
    await _pumpStrip(
      tester,
      visible: true,
      isGuest: false,
      page: _page(const []),
    );
    expect(find.text('Saved addresses'), findsNothing);
  });

  testWidgets('lists address names when visible', (tester) async {
    await _pumpStrip(
      tester,
      visible: true,
      isGuest: false,
      page: _page([_home, _work]),
    );
    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('123 Nile Street, Cairo'), findsNothing);
  });

  testWidgets('tap selects place; same as exclude is ignored', (tester) async {
    final selected = <CarPlace>[];
    await _pumpStrip(
      tester,
      visible: true,
      isGuest: false,
      page: _page([_home, _work]),
      excludePlace: const CarPlace(
        latitude: 30.0444,
        longitude: 31.2357,
        label: 'pickup',
      ),
      onSelected: selected.add,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(selected, hasLength(1));
    expect(selected.single.latitude, 30.06);
    expect(selected.single.longitude, 31.22);
    expect(selected.single.label, '456 Corniche, Cairo');
  });
}
