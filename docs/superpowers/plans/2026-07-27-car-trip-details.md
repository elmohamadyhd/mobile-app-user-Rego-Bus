# Car Trip Details Screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open a private-car trip details screen from soft-browse results: show the selected quote immediately in an expanded soft card, refresh via `GET /private/trips/:id` when signed in, and stub Continue (guest → login gate; signed-in → booking coming soon).

**Architecture:** Extend `features/car` end-to-end. Reuse `CarTripQuote`. Add `CarApi.getTrip` / repository / mapper. Extend `CarBookingNotifier` with `loadTripDetails` + hard/soft error flags. New `CarTripDetailsScreen` + `CarRoutes.details`; results tap calls `selectQuote` + `push`. Guest never calls the details API (`guestModeProvider`).

**Tech Stack:** Flutter, Riverpod, Dio, `flutter_test`, ARB → `flutter gen-l10n`, Skyline tokens, existing `BookingAppBar` / `PrimaryButton` / `showGuestGate`.

**Spec:** `docs/superpowers/specs/2026-07-27-car-trip-details-design.md`

## Global Constraints

- Package imports only (`package:safaria/...`); never relative across directories.
- All user-visible strings via `AppLocalizations` — no hardcoded English/Arabic in widgets.
- Icons only through `AppIcons` — never raw `Icons.*`.
- Directional layout: `EdgeInsetsDirectional` / `AlignmentDirectional`.
- Reuse `CarTripQuote` — no parallel details entity.
- Skip `GET /private/trips/:id` when `guestModeProvider.value != false` (guest or still resolving).
- Soft refresh failures: persistent banner; keep `selectedQuote`. Hard 404: error body + Retry.
- CTA: guest → `showGuestGate(returnTo: CarRoutes.details)`; signed-in → `carBookingComingSoon`.
- No `POST /private/orders`, contact, payment, or voucher.
- Run `dart format` on touched Dart files; `flutter gen-l10n` after ARB edits; `flutter analyze` on touched paths before each commit.

---

## Notes for the implementing engineer

- Package name is **`safaria`** (not `rego`).
- After ARB changes: `flutter gen-l10n` (codegen is gitignored).
- Prefer targeted tests per task; end with `flutter test test/features/car/`.
- `BookingAppBar` already lives under bus presentation — car results already imports it; details screen may do the same (do not lift in this plan).
- Leave `carDetailsComingSoon` ARB key in place even after results stop using it.
- `FakeCarRepository` must gain `getTrip` or every car test that constructs it will fail to compile.

## File map

| File | Responsibility |
|------|----------------|
| `lib/l10n/app_en.arb` / `app_ar.arb` | Details title + error strings |
| `lib/features/car/data/car_api.dart` | `GET /private/trips/:id` |
| `lib/features/car/data/car_dto_mapper.dart` | `quoteFromDetailsEnvelope` |
| `lib/features/car/domain/repositories/car_repository.dart` | `getTrip(int id)` |
| `lib/features/car/data/car_repository_impl.dart` | Implement `getTrip` |
| `test/features/car/data/car_fixtures.dart` | Details 200 / 404 envelopes |
| `test/features/car/data/car_dto_mapper_test.dart` | Mapper coverage |
| `test/features/car/fake_car_repository.dart` | Fake `getTrip` |
| `lib/features/car/presentation/providers/car_booking_providers.dart` | `loadTripDetails` + flags |
| `test/features/car/presentation/car_booking_notifier_test.dart` | Notifier coverage |
| `lib/features/car/presentation/car_routes.dart` | `/car/details` |
| `lib/features/car/presentation/car_trip_details_screen.dart` | NEW screen |
| `lib/features/car/presentation/car_tier_results_screen.dart` | Nav to details |
| `test/features/car/presentation/car_trip_details_screen_test.dart` | NEW widget tests |
| `test/features/car/presentation/car_tier_results_screen_test.dart` | Tap navigates / selects |

---

### Task 1: Localization

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `carDetailsComingSoon` block)
- Modify: `lib/l10n/app_ar.arb` (after `carDetailsComingSoon`)

**Interfaces:**
- Consumes: existing ARB / gen-l10n pipeline
- Produces: `AppLocalizations.carTripDetailsTitle`, `.carTripDetailsNotFound`, `.carTripDetailsRefreshFailed`, `.carTripDetailsMissing`

- [ ] **Step 1: Add English keys**

In `lib/l10n/app_en.arb`, immediately after the `@carDetailsComingSoon` block, insert:

```json
  "carTripDetailsTitle": "Trip details",
  "@carTripDetailsTitle": {
    "description": "App bar title on private-car trip details screen."
  },
  "carTripDetailsNotFound": "This trip is no longer available",
  "@carTripDetailsNotFound": {
    "description": "Hard error when GET /private/trips/:id returns 404."
  },
  "carTripDetailsRefreshFailed": "Couldn't refresh trip details. Showing search results.",
  "@carTripDetailsRefreshFailed": {
    "description": "Soft banner when signed-in details refresh fails for a non-404 reason."
  },
  "carTripDetailsMissing": "No trip selected",
  "@carTripDetailsMissing": {
    "description": "Empty state when details opens without a selectedQuote."
  },
```

Keep valid JSON commas relative to `carSearchSelectBothPlaces`.

- [ ] **Step 2: Add Arabic keys**

In `lib/l10n/app_ar.arb`, immediately after `"carDetailsComingSoon": "التفاصيل قريباً",`, insert:

```json
  "carTripDetailsTitle": "تفاصيل الرحلة",
  "carTripDetailsNotFound": "هذه الرحلة لم تعد متاحة",
  "carTripDetailsRefreshFailed": "تعذّر تحديث تفاصيل الرحلة. يتم عرض نتائج البحث.",
  "carTripDetailsMissing": "لم يتم اختيار رحلة",
```

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`  
Expected: succeeds; getters above exist on `AppLocalizations`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(l10n): add car trip details strings"
```

---

### Task 2: Data layer — `getTrip`

**Files:**
- Modify: `lib/features/car/data/car_api.dart`
- Modify: `lib/features/car/data/car_dto_mapper.dart`
- Modify: `lib/features/car/domain/repositories/car_repository.dart`
- Modify: `lib/features/car/data/car_repository_impl.dart`
- Modify: `test/features/car/data/car_fixtures.dart`
- Modify: `test/features/car/data/car_dto_mapper_test.dart`
- Modify: `test/features/car/fake_car_repository.dart`

**Interfaces:**
- Consumes: Dio, `CarDtoMapper.quoteFromJson`, `ApiException`
- Produces:

```dart
// CarApi
Future<dynamic> getTrip(int id);

// CarDtoMapper
static CarTripQuote quoteFromDetailsEnvelope(dynamic body);

// CarRepository
Future<CarTripQuote> getTrip(int id);

// FakeCarRepository
CarTripQuote? tripResult;
int? lastGetTripId;
bool getTripShouldThrow = false;
ApiException? getTripException;
@override
Future<CarTripQuote> getTrip(int id);
```

- [ ] **Step 1: Add fixtures**

Append to `test/features/car/data/car_fixtures.dart`:

```dart
/// Trimmed from docs/wadeny-apis.md → Private → Show Trip Details (200).
const privateTripDetailsEnvelope = {
  'status': 200,
  'message': 'Trip',
  'errors': <String, dynamic>{},
  'data': {
    'id': 1,
    'rounded': true,
    'go_price': 1000,
    'round_price': 1500,
    'currency': 'EGP',
    'status': true,
    'currency_id': 1,
    'base_currency_id': 1,
    'exchange_rate': '1.00000000',
    'company': {
      'id': 1,
      'name': 'Sky Travel',
      'refundability': true,
      'refund_policy': 'Sky Travel',
      'logo_url':
          'https://demo.safaria.travel/storage/15/6a1f0a7b628ff_images-(1).jpeg',
      'logo_mime_type': 'image/jpeg',
    },
    'from_location': {
      'id': 1,
      'name': 'Cairo',
      'latitude': '30.0441028',
      'longitude': '31.2408498',
    },
    'to_location': {
      'id': 2,
      'name': 'Alexandria',
      'latitude': '31.2452475',
      'longitude': '29.9892346',
    },
    'vehicle': {
      'id': 1,
      'name': 'Hundai',
      'category_id': 1,
      'category_name': 'Sedan',
      'seats_number': 5,
      'model': 'Matrix',
      'year': 2010,
      'big_bags_count': 4,
      'small_bags_count': 1,
      'gear_type': 'automatic',
      'featured_url':
          'https://demo.safaria.travel/storage/16/6a1f0aecdea34_large.jpg',
      'featured_mime_type': 'image/jpeg',
    },
  },
};

const privateTripDetailsNotFoundEnvelope = {
  'status': 404,
  'message': "This record can't be found",
  'errors': <String, dynamic>{},
  'data': <String, dynamic>{},
};
```

- [ ] **Step 2: Write failing mapper tests**

Append to `test/features/car/data/car_dto_mapper_test.dart`:

```dart
    test('maps details envelope to a single quote', () {
      final quote =
          CarDtoMapper.quoteFromDetailsEnvelope(privateTripDetailsEnvelope);
      expect(quote.id, 1);
      expect(quote.goPrice, 1000);
      expect(quote.roundPrice, 1500);
      expect(quote.currency, 'EGP');
      expect(quote.company.name, 'Sky Travel');
      expect(quote.vehicle.categoryName, 'Sedan');
      expect(quote.vehicle.seatsNumber, 5);
    });

    test('throws ApiException on details 404 envelope', () {
      expect(
        () => CarDtoMapper.quoteFromDetailsEnvelope(
          privateTripDetailsNotFoundEnvelope,
        ),
        throwsA(isA<ApiException>()),
      );
    });
```

Add import: `package:safaria/core/network/api_exception.dart`.

- [ ] **Step 3: Run mapper tests — expect FAIL**

Run: `flutter test test/features/car/data/car_dto_mapper_test.dart`  
Expected: FAIL — `quoteFromDetailsEnvelope` missing.

- [ ] **Step 4: Implement mapper**

In `lib/features/car/data/car_dto_mapper.dart`, add:

```dart
  static CarTripQuote quoteFromDetailsEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException.fromEnvelope(envelope);
    }
    return quoteFromJson(data);
  }
```

- [ ] **Step 5: Run mapper tests — expect PASS**

Run: `flutter test test/features/car/data/car_dto_mapper_test.dart`  
Expected: PASS.

- [ ] **Step 6: API + repository interface/impl**

`lib/features/car/data/car_api.dart` — add:

```dart
  Future<dynamic> getTrip(int id) async {
    final res = await _dio.get('/private/trips/$id');
    return res.data;
  }
```

`lib/features/car/domain/repositories/car_repository.dart` — add:

```dart
  Future<CarTripQuote> getTrip(int id);
```

`lib/features/car/data/car_repository_impl.dart` — add:

```dart
  @override
  Future<CarTripQuote> getTrip(int id) {
    return _guard(() async {
      final body = await _api.getTrip(id);
      return CarDtoMapper.quoteFromDetailsEnvelope(body);
    });
  }
```

- [ ] **Step 7: Update `FakeCarRepository`**

Replace/extend `test/features/car/fake_car_repository.dart` so it compiles:

```dart
class FakeCarRepository implements CarRepository {
  FakeCarRepository({this.quotesResult, this.tripResult});

  List<CarTripQuote>? quotesResult;
  CarTripQuote? tripResult;
  CarSearchParams? lastSearchParams;
  int? lastGetTripId;
  bool searchShouldThrow = false;
  bool getTripShouldThrow = false;
  ApiException? searchException;
  ApiException? getTripException;

  static const sampleQuote = CarTripQuote(
    // unchanged fields from existing fake
    id: 1,
    rounded: false,
    goPrice: 69.87,
    roundPrice: 104.81,
    currency: 'SAR',
    company: CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
      refundPolicy: 'Sky Travel',
    ),
    fromLocation: CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation: CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle: CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
      model: 'Matrix',
      year: 2010,
      bigBagsCount: 4,
      smallBagsCount: 1,
      gearType: 'automatic',
    ),
  );

  static const refreshedQuote = CarTripQuote(
    id: 1,
    rounded: true,
    goPrice: 1000,
    roundPrice: 1500,
    currency: 'EGP',
    company: CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
      refundPolicy: 'Sky Travel',
    ),
    fromLocation: CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation: CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle: CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
      model: 'Matrix',
      year: 2010,
      bigBagsCount: 4,
      smallBagsCount: 1,
      gearType: 'automatic',
    ),
  );

  @override
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params) {
    lastSearchParams = params;
    if (searchShouldThrow) {
      throw searchException ??
          const ApiException('Unauthorized', statusCode: 401);
    }
    return Future.value(quotesResult ?? [sampleQuote]);
  }

  @override
  Future<CarTripQuote> getTrip(int id) {
    lastGetTripId = id;
    if (getTripShouldThrow) {
      throw getTripException ??
          const ApiException("This record can't be found", statusCode: 404);
    }
    return Future.value(tripResult ?? refreshedQuote);
  }
}
```

- [ ] **Step 8: Analyze + commit**

Run: `dart format lib/features/car/data lib/features/car/domain test/features/car/data test/features/car/fake_car_repository.dart`  
Run: `flutter analyze lib/features/car/data lib/features/car/domain`  
Run: `flutter test test/features/car/data/car_dto_mapper_test.dart`  
Expected: clean / PASS.

```bash
git add lib/features/car/data lib/features/car/domain test/features/car/data test/features/car/fake_car_repository.dart
git commit -m "feat(car): add GET /private/trips/:id data layer"
```

---

### Task 3: Notifier — `loadTripDetails`

**Files:**
- Modify: `lib/features/car/presentation/providers/car_booking_providers.dart`
- Modify: `test/features/car/presentation/car_booking_notifier_test.dart`

**Interfaces:**
- Consumes: `CarRepository.getTrip`, `ApiException`
- Produces on `CarBookingState`:

```dart
final bool isLoadingTripDetails;
final String? tripDetailsHardError; // set on 404
final String? tripDetailsSoftError; // set on other failures
```

```dart
Future<void> loadTripDetails(int id);
void clearTripDetailsErrors();
```

`loadTripDetails` clears prior details errors, sets `isLoadingTripDetails: true`, on success replaces `selectedQuote`, on 404 sets hard error (keep quote), on other errors sets soft error (keep quote), always clears loading.

- [ ] **Step 1: Write failing notifier tests**

Append to `test/features/car/presentation/car_booking_notifier_test.dart`:

```dart
  test('loadTripDetails replaces selectedQuote on success', () async {
    final repo = FakeCarRepository(tripResult: FakeCarRepository.refreshedQuote);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(repo.lastGetTripId, 1);
    expect(state.selectedQuote?.currency, 'EGP');
    expect(state.selectedQuote?.goPrice, 1000);
    expect(state.isLoadingTripDetails, isFalse);
    expect(state.tripDetailsHardError, isNull);
    expect(state.tripDetailsSoftError, isNull);
  });

  test('loadTripDetails sets hard error on 404 and keeps quote', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException("This record can't be found", statusCode: 404);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(state.selectedQuote?.id, FakeCarRepository.sampleQuote.id);
    expect(state.tripDetailsHardError, isNotNull);
    expect(state.tripDetailsSoftError, isNull);
    expect(state.isLoadingTripDetails, isFalse);
  });

  test('loadTripDetails sets soft error on non-404 and keeps quote', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException('Network error', statusCode: 500);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(state.selectedQuote?.id, FakeCarRepository.sampleQuote.id);
    expect(state.tripDetailsSoftError, isNotNull);
    expect(state.tripDetailsHardError, isNull);
  });

  test('clearTripDetailsErrors clears hard and soft flags', () {
    // After a soft failure, clearTripDetailsErrors nulls both error fields.
    // Implement by calling loadTripDetails then clearTripDetailsErrors.
  });
```

Replace the last test’s comment body with a real implementation:

```dart
  test('clearTripDetailsErrors clears hard and soft flags', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException('Network error', statusCode: 500);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);
    notifier.clearTripDetailsErrors();

    final state = container.read(carBookingProvider);
    expect(state.tripDetailsSoftError, isNull);
    expect(state.tripDetailsHardError, isNull);
  });
```

- [ ] **Step 2: Run notifier tests — expect FAIL**

Run: `flutter test test/features/car/presentation/car_booking_notifier_test.dart`  
Expected: FAIL — missing members / methods.

- [ ] **Step 3: Implement state + notifier methods**

Update `CarBookingState` / `copyWith` / `CarBookingNotifier` in
`lib/features/car/presentation/providers/car_booking_providers.dart`:

```dart
class CarBookingState {
  const CarBookingState({
    this.searchParams,
    this.quotes = const [],
    this.selectedQuote,
    this.isLoadingQuotes = false,
    this.quotesError,
    this.needsAuthRetry = false,
    this.isLoadingTripDetails = false,
    this.tripDetailsHardError,
    this.tripDetailsSoftError,
  });

  final CarSearchParams? searchParams;
  final List<CarTripQuote> quotes;
  final CarTripQuote? selectedQuote;
  final bool isLoadingQuotes;
  final String? quotesError;
  final bool needsAuthRetry;
  final bool isLoadingTripDetails;
  final String? tripDetailsHardError;
  final String? tripDetailsSoftError;

  CarBookingState copyWith({
    CarSearchParams? searchParams,
    List<CarTripQuote>? quotes,
    CarTripQuote? selectedQuote,
    bool? isLoadingQuotes,
    String? quotesError,
    bool? needsAuthRetry,
    bool? isLoadingTripDetails,
    String? tripDetailsHardError,
    String? tripDetailsSoftError,
    bool clearQuotesError = false,
    bool clearSelectedQuote = false,
    bool clearTripDetailsHardError = false,
    bool clearTripDetailsSoftError = false,
  }) {
    return CarBookingState(
      searchParams: searchParams ?? this.searchParams,
      quotes: quotes ?? this.quotes,
      selectedQuote:
          clearSelectedQuote ? null : (selectedQuote ?? this.selectedQuote),
      isLoadingQuotes: isLoadingQuotes ?? this.isLoadingQuotes,
      quotesError: clearQuotesError ? null : (quotesError ?? this.quotesError),
      needsAuthRetry: needsAuthRetry ?? this.needsAuthRetry,
      isLoadingTripDetails:
          isLoadingTripDetails ?? this.isLoadingTripDetails,
      tripDetailsHardError: clearTripDetailsHardError
          ? null
          : (tripDetailsHardError ?? this.tripDetailsHardError),
      tripDetailsSoftError: clearTripDetailsSoftError
          ? null
          : (tripDetailsSoftError ?? this.tripDetailsSoftError),
    );
  }
}
```

Add to `CarBookingNotifier`:

```dart
  Future<void> loadTripDetails(int id) async {
    state = state.copyWith(
      isLoadingTripDetails: true,
      clearTripDetailsHardError: true,
      clearTripDetailsSoftError: true,
    );
    try {
      final quote = await _repo.getTrip(id);
      state = state.copyWith(
        isLoadingTripDetails: false,
        selectedQuote: quote,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        state = state.copyWith(
          isLoadingTripDetails: false,
          tripDetailsHardError: e.message,
        );
      } else {
        state = state.copyWith(
          isLoadingTripDetails: false,
          tripDetailsSoftError: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingTripDetails: false,
        tripDetailsSoftError: e.toString(),
      );
    }
  }

  void clearTripDetailsErrors() {
    state = state.copyWith(
      clearTripDetailsHardError: true,
      clearTripDetailsSoftError: true,
    );
  }
```

Note: UI maps API messages to l10n (`carTripDetailsNotFound` /
`carTripDetailsRefreshFailed`) based on which flag is set — do **not** put
l10n strings in the notifier.

- [ ] **Step 4: Run notifier tests — expect PASS**

Run: `flutter test test/features/car/presentation/car_booking_notifier_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/car/presentation/providers/car_booking_providers.dart test/features/car/presentation/car_booking_notifier_test.dart
git commit -m "feat(car): loadTripDetails with hard/soft error flags"
```

---

### Task 4: Route + `CarTripDetailsScreen`

**Files:**
- Modify: `lib/features/car/presentation/car_routes.dart`
- Create: `lib/features/car/presentation/car_trip_details_screen.dart`

**Interfaces:**
- Consumes: `carBookingProvider`, `guestModeProvider`, `showGuestGate`,
  `BookingAppBar`, `PrimaryButton`, `CarTripQuote`, l10n keys from Task 1
- Produces: `CarRoutes.details = '/car/details'` registered in `carRoutes()`

- [ ] **Step 1: Register route**

In `lib/features/car/presentation/car_routes.dart`:

```dart
import 'package:safaria/features/car/presentation/car_trip_details_screen.dart';

abstract final class CarRoutes {
  static const results = '/car/results';
  static const placePicker = '/car/place-picker';
  static const details = '/car/details';
}

List<RouteBase> carRoutes() => [
      GoRoute(
        path: CarRoutes.results,
        builder: (context, state) => const CarTierResultsScreen(),
      ),
      GoRoute(
        path: CarRoutes.details,
        builder: (context, state) => const CarTripDetailsScreen(),
      ),
      GoRoute(
        path: CarRoutes.placePicker,
        builder: (context, state) {
          final args = state.extra;
          if (args is! CarPlacePickerArgs) {
            return const CarPlacePickerScreen(
              args: CarPlacePickerArgs(title: ''),
            );
          }
          return CarPlacePickerScreen(args: args);
        },
      ),
    ];
```

(`app_router.dart` already spreads `carRoutes()` — no change needed.)

- [ ] **Step 2: Implement `CarTripDetailsScreen`**

Create `lib/features/car/presentation/car_trip_details_screen.dart` as a
`ConsumerStatefulWidget` that:

1. On first frame: if `guestModeProvider.value == false` and `selectedQuote != null`, call `loadTripDetails(selectedQuote.id)`. If guest or `value == null`, skip.
2. App bar: `BookingAppBar(title: l10n.carTripDetailsTitle, subtitle: routeLabel)`.
   - `routeLabel` = `searchParams.from.label → searchParams.to.label` when params exist; else quote location names.
3. Body (`SafeArea` + centered `maxContentWidth` + `SingleChildScrollView`):
   - If `selectedQuote == null` → `carTripDetailsMissing` + text button / back via `context.pop`.
   - Else if `tripDetailsHardError != null` → `carTripDetailsNotFound` + Retry (`loadTripDetails`) using `tripResultsRetry` for the button label + back.
   - Else:
     - If `tripDetailsSoftError != null` → banner with `carTripDetailsRefreshFailed`.
     - If `isLoadingTripDetails` → small `LinearProgressIndicator` under app bar / above card.
     - Expanded soft card (`AppColors.bgElevated`, elevation/shadow like `CarTierCard`, `AppRadius.card`):
       - Wide vehicle image (~160–200 height OK as fixed media size; full width of card)
       - Category · model · year (skip empties)
       - Company row (optional small logo via `Image.network` + name)
       - Spec chips (reuse same seat/bag/gear labels as results; private `_SpecChip` OK — do not import private widgets from `car_tier_card.dart`)
       - Refundable badge + `refundPolicy` text when present
       - Route: `carPickup` / `carDropoff` labels with place text
       - Price + currency (`NumberFormat.decimalPattern` + `priceFor`)
4. `bottomNavigationBar`: price + `PrimaryButton(label: l10n.carContinue, onPressed: …)`
   - Guest (`guestMode.value != false`) → `showGuestGate(context, returnTo: CarRoutes.details, body: l10n.guestGateCarBody)`
   - Signed-in → SnackBar `carBookingComingSoon`
5. Dispose / leave: call `clearTripDetailsErrors()` in `dispose` so returning to results doesn’t keep banners.

Use tokens only (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIcons`). RTL-safe paddings. Scrollable for landscape.

Keep the file focused; extract private widgets (`_ExpandedQuoteCard`, `_PriceFooter`, `_SoftErrorBanner`) in the same file if `build` gets large.

- [ ] **Step 3: Format + analyze**

Run: `dart format lib/features/car/presentation/car_routes.dart lib/features/car/presentation/car_trip_details_screen.dart`  
Run: `flutter analyze lib/features/car/presentation/car_routes.dart lib/features/car/presentation/car_trip_details_screen.dart`  
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_routes.dart lib/features/car/presentation/car_trip_details_screen.dart
git commit -m "feat(car): add trip details screen and route"
```

---

### Task 5: Wire results → details

**Files:**
- Modify: `lib/features/car/presentation/car_tier_results_screen.dart`
- Modify: `test/features/car/presentation/car_tier_results_screen_test.dart`

**Interfaces:**
- Consumes: `CarBookingNotifier.selectQuote`, `CarRoutes.details`
- Produces: card tap navigates; no `carDetailsComingSoon` SnackBar

- [ ] **Step 1: Replace SnackBar tap handler**

In `car_tier_results_screen.dart`, add:

```dart
import 'package:go_router/go_router.dart';
```

Replace the `onTap` body with:

```dart
            onTap: () {
              ref.read(carBookingProvider.notifier).selectQuote(quote);
              context.push(CarRoutes.details);
            },
```

- [ ] **Step 2: Update results widget test**

In `test/features/car/presentation/car_tier_results_screen_test.dart`, ensure the
pump uses a `ProviderScope` + material app that can host `go_router` **or**
assert selection without full router:

Preferred approach (selection-focused, no router mock):

```dart
  testWidgets('tapping a quote card selects it', (tester) async {
    await pumpResults(tester);
    // Ensure quotes loaded — may need searchQuotes seed:
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CarTierResultsScreen)),
    );
    container.read(carBookingProvider.notifier).selectQuote(
          FakeCarRepository.sampleQuote,
        );
    // Better: seed state before pump — extend pumpResults to set quotes
    // and searchParams on the notifier after first frame, then tap card.

    await tester.tap(find.byType(CarTierCard).first);
    await tester.pump();

    expect(
      container.read(carBookingProvider).selectedQuote?.id,
      FakeCarRepository.sampleQuote.id,
    );
  });
```

Implement concretely: update `pumpResults` so after pump it reads the container,
calls `searchQuotes(params)` (or sets quotes via a test helper), `pumpAndSettle`,
then tap `CarTierCard` and assert `selectedQuote`.

If the existing screen already shows cards from an override that only fakes the
repo without calling search, seed via:

```dart
    final element = tester.element(find.byType(CarTierResultsScreen));
    final container = ProviderScope.containerOf(element);
    await container.read(carBookingProvider.notifier).searchQuotes(params);
    await tester.pumpAndSettle();
```

`context.push` in tests without `GoRouter` will throw — wrap the pumped app with
a minimal `GoRouter` that includes `carRoutes()` and an initial location of
`CarRoutes.results`, **or** catch by using `GoRouter` in `MaterialApp.router`.

Minimal router harness:

```dart
    final router = GoRouter(
      initialLocation: CarRoutes.results,
      routes: [
        ...carRoutes(),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [/* fake repo */],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
```

Then: seed quotes → tap card → `expect(router.state.uri.path, CarRoutes.details)`.

- [ ] **Step 3: Run results tests**

Run: `flutter test test/features/car/presentation/car_tier_results_screen_test.dart`  
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_tier_results_screen.dart test/features/car/presentation/car_tier_results_screen_test.dart
git commit -m "feat(car): open trip details from results card tap"
```

---

### Task 6: Details screen widget tests + full car suite

**Files:**
- Create: `test/features/car/presentation/car_trip_details_screen_test.dart`

**Interfaces:**
- Consumes: screen + providers + `guestModeProvider` override if needed
- Produces: coverage for expanded card content, guest skip fetch, soft/hard UI, CTA

- [ ] **Step 1: Write widget tests**

Create `test/features/car/presentation/car_trip_details_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_trip_details_screen.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

import '../fake_car_repository.dart';

void main() {
  const cairo = CarPlace(
    latitude: 30.03,
    longitude: 31.26,
    label: 'Cairo',
  );
  const alex = CarPlace(
    latitude: 31.18,
    longitude: 29.89,
    label: 'Alexandria',
  );

  final params = CarSearchParams(
    from: cairo,
    to: alex,
    rounded: false,
    departDate: DateTime(2026, 7, 31),
  );

  Future<ProviderContainer> pumpDetails(
    WidgetTester tester, {
    required FakeCarRepository repo,
    required bool isGuest,
    bool selectSample = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        carRepositoryProvider.overrideWithValue(repo),
        guestModeProvider.overrideWith(() => _FakeGuest(isGuest)),
      ],
    );
    addTearDown(container.dispose);

    if (selectSample) {
      container.read(carBookingProvider.notifier)
        ..selectQuote(FakeCarRepository.sampleQuote);
      // Also set searchParams for subtitle — via searchQuotes or direct if needed.
      await container.read(carBookingProvider.notifier).searchQuotes(params);
      container
          .read(carBookingProvider.notifier)
          .selectQuote(FakeCarRepository.sampleQuote);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CarTripDetailsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows company and price from selected quote', (tester) async {
    final repo = FakeCarRepository();
    await pumpDetails(tester, repo: repo, isGuest: true);

    expect(find.text('Sky Travel'), findsWidgets);
    expect(find.textContaining('SAR'), findsWidgets);
    expect(repo.lastGetTripId, isNull); // guest skips fetch
  });

  testWidgets('signed-in user refreshes trip details', (tester) async {
    final repo = FakeCarRepository(
      tripResult: FakeCarRepository.refreshedQuote,
    );
    await pumpDetails(tester, repo: repo, isGuest: false);

    expect(repo.lastGetTripId, FakeCarRepository.sampleQuote.id);
    expect(find.textContaining('EGP'), findsWidgets);
  });

  testWidgets('shows soft banner when refresh fails non-404', (tester) async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException('Network error', statusCode: 500);
    await pumpDetails(tester, repo: repo, isGuest: false);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CarTripDetailsScreen)),
    );
    expect(find.text(l10n.carTripDetailsRefreshFailed), findsOneWidget);
    expect(find.text('Sky Travel'), findsWidgets);
  });

  testWidgets('shows hard error on 404', (tester) async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException("This record can't be found", statusCode: 404);
    await pumpDetails(tester, repo: repo, isGuest: false);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CarTripDetailsScreen)),
    );
    expect(find.text(l10n.carTripDetailsNotFound), findsOneWidget);
  });

  testWidgets('continue shows booking coming soon when signed in',
      (tester) async {
    final repo = FakeCarRepository();
    await pumpDetails(tester, repo: repo, isGuest: false);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CarTripDetailsScreen)),
    );
    expect(find.text(l10n.carBookingComingSoon), findsOneWidget);
  });
}
```

Implement `_FakeGuest` as a minimal `GuestController` / `AsyncNotifier<bool>`
override matching how other tests override `guestModeProvider` in this repo.
If no existing pattern, use:

```dart
class _FakeGuest extends GuestController {
  _FakeGuest(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}
```

Inspect `GuestController` in `auth_providers.dart` and match its superclass.
If override is awkward, inject a `ValueNotifier`-style test double already used
elsewhere — follow the closest existing test.

Add missing import for `ApiException`.

- [ ] **Step 2: Run details + full car tests**

Run: `flutter test test/features/car/presentation/car_trip_details_screen_test.dart`  
Run: `flutter test test/features/car/`  
Expected: all PASS.

- [ ] **Step 3: Analyze touched presentation paths**

Run: `flutter analyze lib/features/car test/features/car`  
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add test/features/car/presentation/car_trip_details_screen_test.dart
git commit -m "test(car): cover trip details screen behaviors"
```

---

## Spec coverage checklist (self-review)

| Spec requirement | Task |
|------------------|------|
| l10n title + soft/hard strings | 1 (+ `carTripDetailsMissing` for empty) |
| `GET /private/trips/:id` API/repo/mapper | 2 |
| Reuse `CarTripQuote` | 2–4 |
| `loadTripDetails` + hard/soft flags | 3 |
| Guest skips fetch | 4 + 6 |
| Expanded soft card layout C | 4 |
| Sticky CTA guest gate / coming soon | 4 + 6 |
| Results `selectQuote` + push | 5 |
| 404 hard / other soft / keep quote | 3 + 6 |
| No booking APIs | all (never introduced) |

## Placeholder / consistency notes

- Soft error UI uses l10n `carTripDetailsRefreshFailed` (not raw API message).
- Hard error UI uses l10n `carTripDetailsNotFound`.
- Retry button label: reuse `tripResultsRetry`.
- Route constant name is `CarRoutes.details` (not `detail`).
