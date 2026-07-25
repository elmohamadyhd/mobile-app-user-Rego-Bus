# Addresses Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Profile → Addresses “coming soon” with a full address-book flow backed by `/profile/address-book` CRUD APIs, matching Skyline screen 29.

**Architecture:** Standalone `lib/features/addresses/` slice (data/domain/presentation) mirroring wallet. Extract map-first location picking into `lib/shared/` so addresses and car both use it without cross-feature imports.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`, no codegen), go_router, Freezed (entities only), Dio.

**Spec:** `docs/superpowers/specs/2026-07-25-addresses-feature-design.md` — read it first.

**Verification:** Every task ends with `flutter analyze` and/or targeted `flutter test`. Run `dart run build_runner build --delete-conflicting-outputs` after Freezed edits.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/features/addresses/domain/entities/saved_address.dart` | `SavedAddress`, `MapLocation` |
| `lib/features/addresses/domain/entities/address_page.dart` | Paginated list wrapper |
| `lib/features/addresses/domain/repositories/addresses_repository.dart` | Abstract CRUD |
| `lib/features/addresses/data/addresses_api.dart` | Dio transport |
| `lib/features/addresses/data/addresses_dto_mapper.dart` | Envelope parsing |
| `lib/features/addresses/data/addresses_repository_impl.dart` | Repository impl |
| `lib/features/addresses/presentation/providers/addresses_providers.dart` | Riverpod wiring |
| `lib/features/addresses/presentation/addresses_routes.dart` | Route constants + `GoRoute`s |
| `lib/features/addresses/presentation/addresses_screen.dart` | List UI |
| `lib/features/addresses/presentation/address_form_screen.dart` | Create/edit/delete UI |
| `lib/features/addresses/presentation/widgets/addresses_app_bar.dart` | Pushed-screen chrome |
| `lib/features/addresses/presentation/widgets/address_card.dart` | List row |
| `lib/features/addresses/presentation/widgets/add_address_button.dart` | Dashed CTA |
| `lib/shared/models/map_place.dart` | Shared lat/lng/label model |
| `lib/shared/widgets/map_place_picker_args.dart` | Picker route args |
| `lib/shared/widgets/map_place_picker_screen.dart` | Map-first picker (extracted from car) |
| `lib/shared/widgets/place_picker_routes.dart` | `/place-picker` constant |

---

### Task 1: Domain entities and repository interface

**Files:**
- Create: `lib/features/addresses/domain/entities/saved_address.dart`
- Create: `lib/features/addresses/domain/entities/address_page.dart`
- Create: `lib/features/addresses/domain/repositories/addresses_repository.dart`

- [ ] **Step 1: Create `saved_address.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_address.freezed.dart';

@freezed
abstract class MapLocation with _$MapLocation {
  const factory MapLocation({
    required double latitude,
    required double longitude,
    required String addressName,
  }) = _MapLocation;
}

@freezed
abstract class SavedAddress with _$SavedAddress {
  const factory SavedAddress({
    required int id,
    required String name,
    required MapLocation mapLocation,
    String? phone,
    String? notes,
    String? whatsappShareLink,
  }) = _SavedAddress;
}
```

- [ ] **Step 2: Create `address_page.dart`**

```dart
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
```

- [ ] **Step 3: Create repository interface**

```dart
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
```

- [ ] **Step 4: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/addresses/domain`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/addresses/domain
git commit -m "feat(addresses): add domain entities and repository interface"
```

---

### Task 2: AddressesDtoMapper — TDD

**Files:**
- Create: `test/features/addresses/data/addresses_fixtures.dart`
- Create: `test/features/addresses/data/addresses_dto_mapper_test.dart`
- Create: `lib/features/addresses/data/addresses_dto_mapper.dart`

- [ ] **Step 1: Write fixtures** (`test/features/addresses/data/addresses_fixtures.dart`)

```dart
const listEnvelope = {
  'status': 200,
  'message': 'Customer addresses list',
  'errors': {},
  'data': [
    {
      'id': 22,
      'city': null,
      'name': 'Home',
      'phone': '1554052685',
      'notes': 'Ring twice',
      'whatsapp_share_link': 'https://example.com/wa',
      'map_location': {
        'lat': 24.2222,
        'lng': 46.5555,
        'address_name': '12 El Tahrir St',
      },
    },
  ],
  'pagination': {
    'total': 1,
    'lastPage': 1,
    'perPage': 15,
    'currentPage': 1,
    'nextPageUrl': null,
    'previousPageUrl': null,
  },
};

const createEnvelope = {
  'status': 200,
  'message': 'Created',
  'errors': {},
  'data': {
    'id': 23,
    'city': null,
    'name': 'Work',
    'phone': '1090510796',
    'notes': null,
    'whatsapp_share_link': 'https://example.com/wa2',
    'map_location': {
      'lat': 31.04,
      'lng': 31.37,
      'address_name': 'Smart Village B12',
    },
  },
};
```

- [ ] **Step 2: Write failing mapper tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/addresses/data/addresses_dto_mapper.dart';

import 'addresses_fixtures.dart';

void main() {
  group('AddressesDtoMapper', () {
    test('pageFromEnvelope parses list + pagination', () {
      final page = AddressesDtoMapper.pageFromEnvelope(listEnvelope);
      expect(page.items, hasLength(1));
      expect(page.items.first.id, 22);
      expect(page.items.first.name, 'Home');
      expect(page.items.first.mapLocation.addressName, '12 El Tahrir St');
      expect(page.items.first.mapLocation.latitude, 24.2222);
      expect(page.currentPage, 1);
      expect(page.hasNextPage, isFalse);
    });

    test('addressFromEnvelope parses single record', () {
      final address = AddressesDtoMapper.addressFromEnvelope(createEnvelope);
      expect(address.id, 23);
      expect(address.name, 'Work');
      expect(address.mapLocation.longitude, 31.37);
    });
  });
}
```

- [ ] **Step 3: Run test — expect FAIL**

Run: `flutter test test/features/addresses/data/addresses_dto_mapper_test.dart`
Expected: FAIL — class not defined

- [ ] **Step 4: Implement mapper**

```dart
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
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `flutter test test/features/addresses/data/addresses_dto_mapper_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/addresses/data/addresses_dto_mapper.dart test/features/addresses/data
git commit -m "feat(addresses): add DTO mapper with tests"
```

---

### Task 3: API + repository implementation — TDD

**Files:**
- Create: `lib/features/addresses/data/addresses_api.dart`
- Create: `lib/features/addresses/data/addresses_repository_impl.dart`
- Create: `test/features/addresses/data/addresses_repository_impl_test.dart`

- [ ] **Step 1: Write `addresses_api.dart`**

```dart
import 'package:dio/dio.dart';

class AddressesApi {
  AddressesApi(this._dio);

  final Dio _dio;

  Future<dynamic> list({int page = 1}) async {
    final res = await _dio.get(
      '/profile/address-book',
      queryParameters: {'page': page},
    );
    return res.data;
  }

  Future<dynamic> create(Map<String, dynamic> body) async {
    final res = await _dio.post('/profile/address-book', data: body);
    return res.data;
  }

  Future<dynamic> update(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/profile/address-book/$id', data: body);
    return res.data;
  }

  Future<void> delete(int id) async {
    await _dio.delete('/profile/address-book/$id');
  }
}
```

- [ ] **Step 2: Write repository impl**

```dart
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
```

- [ ] **Step 3: Write repository test with mock API**

Use a simple fake `AddressesApi` subclass or manual mock returning `listEnvelope` /
`createEnvelope` from fixtures. Assert `list()` returns one item and `create()`
returns id 23.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/addresses/data/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/addresses/data test/features/addresses/data/addresses_repository_impl_test.dart
git commit -m "feat(addresses): add API layer and repository implementation"
```

---

### Task 4: Extract shared MapPlace model

**Files:**
- Create: `lib/shared/models/map_place.dart`
- Modify: `lib/features/car/domain/entities/car_place.dart`
- Modify: `lib/features/car/presentation/widgets/car_place_field.dart` (mapping only if needed)

- [ ] **Step 1: Create `map_place.dart`**

```dart
import 'package:safaria/l10n/app_localizations.dart';

final class MapPlace {
  const MapPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  static final _coordinatesLabel = RegExp(
    r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$',
  );

  static bool looksLikeCoordinates(String text) =>
      _coordinatesLabel.hasMatch(text);

  String displayLabel(AppLocalizations l10n) {
    if (label.isEmpty || looksLikeCoordinates(label)) {
      return l10n.carPlaceSelectedLocation;
    }
    return label;
  }

  bool sameCoordinates(MapPlace other) {
    const epsilon = 0.00001;
    return (latitude - other.latitude).abs() < epsilon &&
        (longitude - other.longitude).abs() < epsilon;
  }
}
```

- [ ] **Step 2: Make `CarPlace` a thin typedef/wrapper**

Option A (minimal churn): keep `CarPlace` but delegate `displayLabel` / coordinate
helpers to `MapPlace` via conversion extensions:

```dart
// lib/features/car/domain/entities/car_place.dart
import 'package:safaria/shared/models/map_place.dart';

typedef CarPlace = MapPlace;

extension CarPlaceX on MapPlace {
  CarPlace get asCarPlace => this;
}
```

If typedef causes import churn, keep `CarPlace` class with factory `fromMapPlace`
and `toMapPlace()` — pick whichever compiles with fewer car-file edits.

- [ ] **Step 3: Run car tests**

Run: `flutter test test/features/car/`

- [ ] **Step 4: Commit**

```bash
git add lib/shared/models/map_place.dart lib/features/car/domain/entities/car_place.dart
git commit -m "refactor(places): extract shared MapPlace model"
```

---

### Task 5: Extract shared map place picker from car

**Files:**
- Create: `lib/shared/widgets/map_place_picker_args.dart`
- Create: `lib/shared/widgets/map_place_picker_screen.dart`
- Create: `lib/shared/widgets/place_picker_routes.dart`
- Modify: `lib/features/car/presentation/car_place_picker_screen.dart` — re-export or thin delegate
- Modify: `lib/features/car/presentation/car_routes.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Create args + routes**

```dart
// map_place_picker_args.dart
import 'package:safaria/shared/models/map_place.dart';

final class MapPlacePickerArgs {
  const MapPlacePickerArgs({
    required this.title,
    this.initial,
    this.showUseMyLocation = false,
  });

  final String title;
  final MapPlace? initial;
  final bool showUseMyLocation;
}
```

```dart
// place_picker_routes.dart
abstract final class PlacePickerRoutes {
  static const picker = '/place-picker';
}
```

- [ ] **Step 2: Move picker implementation**

Copy `CarPlacePickerScreen` body into `MapPlacePickerScreen`, replacing
`CarPlace` → `MapPlace`, `CarPlacePickerArgs` → `MapPlacePickerArgs`.
Keep imports on `core/places/*`, `AuthBackButton`, `PrimaryButton`.

- [ ] **Step 3: Replace car screen with export/delegate**

```dart
// car_place_picker_screen.dart — keep class name for stable car imports
export 'package:safaria/shared/widgets/map_place_picker_screen.dart'
    show MapPlacePickerScreen as CarPlacePickerScreen;
```

Or keep a 10-line wrapper that converts args at the boundary — whichever keeps
car tests green with least churn.

- [ ] **Step 4: Register shared route in `app_router.dart`**

```dart
GoRoute(
  path: PlacePickerRoutes.picker,
  builder: (context, state) {
    final args = state.extra;
    return MapPlacePickerScreen(
      args: args is MapPlacePickerArgs ? args : const MapPlacePickerArgs(title: ''),
    );
  },
),
```

Update car route to push `PlacePickerRoutes.picker` if it used a car-local path.

- [ ] **Step 5: Run car picker tests**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets lib/features/car/presentation lib/core/router/app_router.dart
git commit -m "refactor(places): extract shared map place picker screen"
```

---

### Task 6: Addresses providers

**Files:**
- Create: `lib/features/addresses/presentation/providers/addresses_providers.dart`

- [ ] **Step 1: Wire providers**

```dart
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
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/addresses/presentation/providers`

- [ ] **Step 3: Commit**

```bash
git add lib/features/addresses/presentation/providers
git commit -m "feat(addresses): add Riverpod providers"
```

---

### Task 7: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add all keys from the design spec** (`addressesScreenTitle` through
  `addressFormLocationRequired`) to both ARB files with `@key` descriptions in
  English template.

Arabic examples:
- `addressesScreenTitle`: `العناوين المحفوظة`
- `addressesAddNew`: `إضافة عنوان جديد`
- `addressFormCreateTitle`: `عنوان جديد`
- `addressFormEditTitle`: `تعديل العنوان`

- [ ] **Step 2: Regenerate l10n**

Run: `flutter gen-l10n`

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "feat(addresses): add localization strings"
```

---

### Task 8: Presentation widgets

**Files:**
- Create: `lib/features/addresses/presentation/widgets/addresses_app_bar.dart`
- Create: `lib/features/addresses/presentation/widgets/address_card.dart`
- Create: `lib/features/addresses/presentation/widgets/add_address_button.dart`
- Modify: `lib/core/theme/app_icons.dart` (add `edit` if missing)

- [ ] **Step 1: `AddressesAppBar`** — copy structure from `WalletAppBar`
  (`lib/features/wallet/presentation/widgets/wallet_app_bar.dart`), rename only.

- [ ] **Step 2: `AddressCard`**

```dart
// Key structure — full file in implementation
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onTap,
    required this.onEdit,
    required this.iconTintIndex,
  });

  final SavedAddress address;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final int iconTintIndex;

  // Row: tinted 42×42 icon box (AppIcons.locationTo), Expanded column
  // (name AppTypography.title w800, addressName body secondary maxLines 2),
  // IconButton(AppIcons.edit, onEdit). InkWell onTap on whole card.
  // iconTintIndex % 3 rotates primaryTint / secondary tint / neutral bg.
}
```

- [ ] **Step 3: `AddAddressButton`** — dashed border (`Border.all` width 1.5,
  `AppColors.hairline`, style: dashed via `CustomPaint` or `DottedBorder` if
  already in pubspec; otherwise `Border.all` solid is acceptable fallback per
  YAGNI), centred row with `AppIcons.add` + `l10n.addressesAddNew`.

- [ ] **Step 4: Analyze widgets**

Run: `flutter analyze lib/features/addresses/presentation/widgets`

- [ ] **Step 5: Commit**

```bash
git add lib/features/addresses/presentation/widgets lib/core/theme/app_icons.dart
git commit -m "feat(addresses): add list screen widgets"
```

---

### Task 9: Addresses list screen + tests

**Files:**
- Create: `lib/features/addresses/presentation/addresses_screen.dart`
- Create: `lib/features/addresses/presentation/addresses_routes.dart`
- Create: `test/features/addresses/presentation/addresses_screen_test.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: `addresses_routes.dart`**

```dart
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
```

- [ ] **Step 2: Implement `AddressesScreen`**

`ConsumerWidget` with `ref.watch(addressesProvider)`. Scaffold +
`AddressesAppBar(title: l10n.addressesScreenTitle)`. Body `when`:
loading spinner, error column (message + `TextButton` retry → `refresh()`),
data → `RefreshIndicator` + `NotificationListener<ScrollNotification>` to call
`loadMore()` near bottom. `LayoutBuilder` + `AppBreakpoints.maxContentWidth`.
Empty list → empty title/subtitle + `AddAddressButton`. Non-empty →
`AddressCard` per item + `AddAddressButton` at end. Add navigates
`context.push(AddressesRoutes.create)`.

- [ ] **Step 3: Spread routes in `app_router.dart`**

```dart
...addressesRoutes(),
```

- [ ] **Step 4: Widget test**

Override `addressesProvider` with `AsyncData(AddressPage(items: [...], ...))`.
Pump under `Locale('en')`. Expect title, address name, address line. Override
with empty list — expect empty title. Tap add — expect navigation (use `GoRouter`
test harness or verify `AddressesRoutes.create` pushed).

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/addresses/presentation/addresses_screen_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/addresses/presentation/addresses_screen.dart lib/features/addresses/presentation/addresses_routes.dart lib/core/router/app_router.dart test/features/addresses/presentation
git commit -m "feat(addresses): add addresses list screen"
```

---

### Task 10: Address form screen + tests

**Files:**
- Create: `lib/features/addresses/presentation/address_form_screen.dart`
- Create: `test/features/addresses/presentation/address_form_screen_test.dart`

- [ ] **Step 1: Implement form screen**

`AddressFormScreen({this.addressId})` — `addressId == null` → create.

State: `_nameController`, `_phoneController`, `_notesController`, `MapLocation? _location`.

Edit mode: on first frame, find address in `addressesProvider` by id **or**
call `repository.list` and pick (prefer reading from list provider to avoid
extra GET endpoint — API has no single-get).

Form fields per design spec. Location row `ListTile` →

```dart
final picked = await context.push<MapPlace>(
  PlacePickerRoutes.picker,
  extra: MapPlacePickerArgs(
    title: l10n.addressFormLocationLabel,
    initial: _location == null
        ? null
        : MapPlace(
            latitude: _location!.latitude,
            longitude: _location!.longitude,
            label: _location!.addressName,
          ),
    showUseMyLocation: true,
  ),
);
if (picked != null) setState(() => _location = MapLocation(
  latitude: picked.latitude,
  longitude: picked.longitude,
  addressName: picked.label,
));
```

Save: validate → `repository.create` or `update` → snackbar `addressFormSaved`
→ `context.pop()`. Delete (edit only): dialog → `ref.read(addressesProvider.notifier).delete(id)` → snackbar → pop.

- [ ] **Step 2: Widget tests**

- Create mode shows `addressFormCreateTitle`, save disabled until name + location set.
- Edit mode pre-fills name from fake provider.
- Delete button only in edit mode.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/addresses/presentation/address_form_screen_test.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/addresses/presentation/address_form_screen.dart test/features/addresses/presentation/address_form_screen_test.dart
git commit -m "feat(addresses): add create/edit address form screen"
```

---

### Task 11: Profile integration

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `test/features/profile/profile_screen_test.dart`

- [ ] **Step 1: Wire profile menu**

Replace addresses `_showComingSoon` with guest gate + `context.push(AddressesRoutes.list)` mirroring wallet block (lines 44-54). Add import for `addresses_routes.dart`.

- [ ] **Step 2: Extend profile tests**

Add test: signed-in user taps Addresses → navigates (mock router). Guest taps
Addresses → goes to login with `returnTo: AddressesRoutes.list`.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/profile/profile_screen_test.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/profile test/features/profile
git commit -m "feat(profile): wire addresses menu to address book flow"
```

---

### Task 12: Final verification

- [ ] **Step 1: Full analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full addresses + profile + car regression**

Run: `flutter test test/features/addresses test/features/profile test/features/car/presentation/car_place_picker_screen_test.dart`

- [ ] **Step 3: Format**

Run: `dart format lib/features/addresses lib/shared/models/map_place.dart lib/shared/widgets/map_place_picker_screen.dart`

---

## Plan self-review (spec coverage)

| Spec requirement | Task |
|------------------|------|
| CRUD via `/profile/address-book` | Tasks 2–3, 10 |
| List UI screen 29 | Tasks 8–9 |
| Add / edit / delete | Task 10 |
| Shared map picker (no car import) | Tasks 4–5 |
| Guest gate from profile | Task 11 |
| Pagination load-more | Tasks 6, 9 |
| Localization | Task 7 |
| RTL / responsive | Tasks 8–10 (LayoutBuilder, directional padding) |
| Omit default badge / city picker | Design decision — no task |
| Tests | Tasks 2–3, 9–11 |

## Execution handoff

**Plan saved to `docs/superpowers/plans/2026-07-25-addresses-feature.md`.**

**Spec saved to `docs/superpowers/specs/2026-07-25-addresses-feature-design.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.
2. **Inline Execution** — run tasks in this session with checkpoints.

Which approach would you like?
