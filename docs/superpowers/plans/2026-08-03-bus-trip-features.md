# Bus Trip Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Execute on the **current branch**. Commits only if the user explicitly asks.

**Goal:** Bind trip `features[]` from the bus API (id, name, icon URL) into
results cards and trip details, replacing placeholder amenities.

**Architecture:** Freezed `BusFeature` on `BusTripSummary.features`. Mapper
reads `features[]` (no placeholder fill). UI uses network icons with Phosphor
fallback; labels via presentation helper + ARB for known ids.

**Tech Stack:** Flutter, Freezed, Dio JSON maps, `Image.network`, Phosphor,
`AppLocalizations`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-03-bus-trip-features-design.md`

## Global Constraints

- Package imports: `package:safaria/...` only.
- Icons for chrome/fallback: `PhosphorIconsLight.*` only.
- Tokens: `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`.
- All user-facing strings via `AppLocalizations` (known ids); unknown → API `name`.
- Directional insets (`EdgeInsetsDirectional`).
- Empty `features` → hide amenity UI (no `BusPlaceholderAmenities`).
- Do not commit unless the user asks.
- After Freezed / ARB edits: `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`.

## File map

| File | Action |
|------|--------|
| `lib/features/bus/domain/entities/bus_feature.dart` | Create |
| `lib/features/bus/domain/entities/bus_trip.dart` | Modify — `features`, remove placeholders |
| `lib/features/bus/data/bus_dto_mapper.dart` | Modify — map `features[]` |
| `lib/features/bus/presentation/widgets/feature_label.dart` | Create — id → ARB |
| `lib/features/bus/presentation/widgets/feature_icon.dart` | Create — network + Phosphor |
| `lib/features/bus/presentation/widgets/amenity_icon.dart` | Keep — Phosphor heuristics |
| `lib/features/bus/presentation/widgets/amenity_icons_row.dart` | Modify — `List<BusFeature>` |
| `lib/features/bus/presentation/widgets/amenity_chip.dart` | Modify — take `BusFeature` |
| `lib/features/bus/presentation/widgets/trip_card.dart` | Modify — `trip.features` |
| `lib/features/bus/presentation/trip_details_screen.dart` | Modify — features + hide when empty |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Modify — `amenityDvd`, `amenityGps` |
| `test/features/bus/data/bus_dto_mapper_test.dart` | Modify |
| `test/features/bus/data/bus_fixtures.dart` | Modify if needed |
| `test/features/bus/presentation/widgets/feature_label_test.dart` | Create |
| `test/features/bus/presentation/trip_details_screen_test.dart` | Modify |
| `test/features/bus/fake_bus_repository.dart` | No change unless compile breaks |

---

### Task 1: `BusFeature` entity + `BusTripSummary.features`

**Files:**
- Create: `lib/features/bus/domain/entities/bus_feature.dart`
- Modify: `lib/features/bus/domain/entities/bus_trip.dart`
- Test: `test/features/bus/domain/bus_trip_test.dart` (extend) or
  `test/features/bus/data/bus_dto_mapper_test.dart` merge test

**Produces:**
- `BusFeature({required String id, required String name, String? iconUrl})`
- `BusTripSummary.features` as `@Default([]) List<BusFeature>`
- `mergeEnrichment` copies `detail.features` when non-empty

**Consumes:** none

- [ ] **Step 1: Write failing merge test**

Add to `test/features/bus/data/bus_dto_mapper_test.dart`:

```dart
test('mergeEnrichment keeps cached features when detail features empty', () {
  final cached = BusDtoMapper.tripsPageFromEnvelope(tripsSearchEnvelope)
      .trips
      .first
      .copyWith(
        features: const [
          BusFeature(id: 'wifi', name: 'Wi Fi'),
        ],
      );
  final detail =
      BusDtoMapper.tripFromEnvelope(tripByIdEmptyStationsEnvelope);
  final merged = cached.mergeEnrichment(detail);
  expect(merged.features, hasLength(1));
  expect(merged.features.first.id, 'wifi');
});
```

(Import `bus_feature.dart`. This fails until entity + merge exist.)

- [ ] **Step 2: Create `bus_feature.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_feature.freezed.dart';

@freezed
abstract class BusFeature with _$BusFeature {
  const factory BusFeature({
    required String id,
    required String name,
    String? iconUrl,
  }) = _BusFeature;
}
```

- [ ] **Step 3: Update `bus_trip.dart`**

- Delete `BusPlaceholderAmenities`.
- Replace amenities field with:

```dart
@Default([]) List<BusFeature> features,
```

- Import `bus_feature.dart`.
- In `mergeEnrichment`:

```dart
features: detail.features.isNotEmpty ? detail.features : features,
```

- [ ] **Step 4: Codegen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Fix any compile breaks that still reference `amenities` / `BusPlaceholderAmenities`
in fakes/tests by switching to `features: const []` or explicit sample features
(minimal stubs only — full UI wiring is later tasks).

- [ ] **Step 5: Run merge test**

```bash
flutter test test/features/bus/data/bus_dto_mapper_test.dart --name mergeEnrichment
```

Expected: PASS for the new features merge case (mapper still returns `[]`
features until Task 2 — that is fine for this merge test because we
`copyWith` on cached).

---

### Task 2: Map API `features[]` in `BusDtoMapper`

**Files:**
- Modify: `lib/features/bus/data/bus_dto_mapper.dart`
- Modify: `test/features/bus/data/bus_dto_mapper_test.dart`
- Optional: add features sample into a fixture clone inside the test

**Consumes:** `BusFeature`, `BusTripSummary.features`

**Produces:** `tripFromJson` populates `features` from JSON

- [ ] **Step 1: Write failing mapper tests**

```dart
test('maps trip features list with icon urls', () {
  final envelope = Map<String, dynamic>.from(tripsSearchEnvelope);
  final data = List<Map<String, dynamic>>.from(envelope['data'] as List);
  final tripJson = Map<String, dynamic>.from(data.first);
  tripJson['features'] = [
    {
      'id': 'wifi',
      'name': 'Wi Fi',
      'icon': 'https://example.com/wifi.webp',
    },
    {
      'id': 'ac',
      'name': 'Air Conditioner',
      'icon': 'https://example.com/ac.webp',
    },
    {'id': '', 'name': 'Bad'},
    {'id': 'gps', 'name': 'GPS', 'icon': ''},
  ];
  data[0] = tripJson;
  envelope['data'] = data;

  final trip = BusDtoMapper.tripsPageFromEnvelope(envelope).trips.first;
  expect(trip.features, hasLength(3));
  expect(trip.features[0].id, 'wifi');
  expect(trip.features[0].iconUrl, 'https://example.com/wifi.webp');
  expect(trip.features[2].id, 'gps');
  expect(trip.features[2].iconUrl, isNull);
});

test('absent features yields empty list not placeholders', () {
  final trip =
      BusDtoMapper.tripsPageFromEnvelope(tripsSearchEnvelope).trips.first;
  expect(trip.features, isEmpty);
});
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/bus/data/bus_dto_mapper_test.dart --name "maps trip features"
```

Expected: FAIL (features always empty / field unused).

- [ ] **Step 3: Implement mapper helpers + wiring**

In `bus_dto_mapper.dart`, add:

```dart
static List<BusFeature> _featuresFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <BusFeature>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final id = _string(item['id'])?.trim() ?? '';
    final name = _string(item['name'])?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) continue;
    out.add(
      BusFeature(
        id: id,
        name: name,
        iconUrl: _nonEmptyUrl(item['icon']),
      ),
    );
  }
  return out;
}
```

In `tripFromJson`, pass:

```dart
features: _featuresFromJson(json['features']),
```

Import `bus_feature.dart`.

- [ ] **Step 4: Run mapper tests**

```bash
flutter test test/features/bus/data/bus_dto_mapper_test.dart
```

Expected: PASS.

---

### Task 3: Feature labels + ARB keys

**Files:**
- Create: `lib/features/bus/presentation/widgets/feature_label.dart`
- Create: `test/features/bus/presentation/widgets/feature_label_test.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

**Consumes:** `BusFeature`
**Produces:** `String featureLabel(AppLocalizations l10n, BusFeature feature)`

- [ ] **Step 1: Add ARB keys**

`app_en.arb` (near existing amenity keys):

```json
"amenityDvd": "DVD",
"@amenityDvd": {
  "description": "Amenity label for onboard DVD / entertainment."
},
"amenityGps": "GPS",
"@amenityGps": {
  "description": "Amenity label for GPS tracking."
},
```

`app_ar.arb`:

```json
"amenityDvd": "دي في دي",
"amenityGps": "جي بي إس",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write failing label tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/feature_label.dart';
import 'package:safaria/l10n/app_localizations.dart';

void main() {
  testWidgets('known ids resolve to ARB; unknown uses name', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      featureLabel(l10n, const BusFeature(id: 'wifi', name: 'Wi Fi')),
      'Wi-Fi',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'ac', name: 'Air Conditioner')),
      'A/C',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'dvd', name: 'DVD')),
      'DVD',
    );
    expect(
      featureLabel(l10n, const BusFeature(id: 'gps', name: 'GPS tracking')),
      'GPS',
    );
    expect(
      featureLabel(
        l10n,
        const BusFeature(id: 'snack-bar', name: 'Snack Bar'),
      ),
      'Snack Bar',
    );
  });
}
```

- [ ] **Step 3: Implement `feature_label.dart`**

```dart
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/l10n/app_localizations.dart';

String featureLabel(AppLocalizations l10n, BusFeature feature) {
  switch (feature.id.toLowerCase()) {
    case 'wifi':
      return l10n.amenityWifi;
    case 'ac':
      return l10n.amenityAC;
    case 'sockets':
    case 'plug':
    case 'power':
      return l10n.amenitySockets;
    case 'wc':
      return l10n.amenityWc;
    case 'dvd':
      return l10n.amenityDvd;
    case 'gps':
      return l10n.amenityGps;
    default:
      return feature.name;
  }
}
```

- [ ] **Step 4: Run label test**

```bash
flutter test test/features/bus/presentation/widgets/feature_label_test.dart
```

Expected: PASS.

---

### Task 4: `FeatureIcon` + amenity row/chip

**Files:**
- Create: `lib/features/bus/presentation/widgets/feature_icon.dart`
- Modify: `lib/features/bus/presentation/widgets/amenity_icons_row.dart`
- Modify: `lib/features/bus/presentation/widgets/amenity_chip.dart`
- Keep: `amenity_icon.dart` (`amenityIconFor`) for Phosphor fallback

**Consumes:** `BusFeature`, `amenityIconFor`, `featureLabel` (chip)
**Produces:** network-aware icon widgets used by card/details

- [ ] **Step 1: Implement `FeatureIcon`**

```dart
import 'package:flutter/material.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_icon.dart';

class FeatureIcon extends StatelessWidget {
  const FeatureIcon({
    super.key,
    required this.feature,
    this.size = 15,
    this.color = AppColors.textSecondary,
  });

  final BusFeature feature;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      amenityIconFor(feature.id.isNotEmpty ? feature.id : feature.name),
      size: size,
      color: color,
    );
    final url = feature.iconUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(width: size, height: size, child: fallback);
      },
    );
  }
}
```

- [ ] **Step 2: Update `AmenityIconsRow`**

```dart
class AmenityIconsRow extends StatelessWidget {
  const AmenityIconsRow({super.key, required this.features, this.size = 15});

  final List<BusFeature> features;
  final double size;

  @override
  Widget build(BuildContext context) {
    final items = features.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in items)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: FeatureIcon(feature: f, size: size),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Update `AmenityChip`**

```dart
class AmenityChip extends StatelessWidget {
  const AmenityChip({super.key, required this.feature, required this.label});

  final BusFeature feature;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FeatureIcon(
            feature: feature,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze amenity widgets**

```bash
dart analyze lib/features/bus/presentation/widgets/feature_icon.dart \
  lib/features/bus/presentation/widgets/amenity_icons_row.dart \
  lib/features/bus/presentation/widgets/amenity_chip.dart
```

Expected: No issues (call sites still broken until Task 5 — if analyze on
whole project, fix compile errors in Task 5 immediately after).

---

### Task 5: Wire trip card + trip details + screen tests

**Files:**
- Modify: `lib/features/bus/presentation/widgets/trip_card.dart`
- Modify: `lib/features/bus/presentation/trip_details_screen.dart`
- Modify: `test/features/bus/presentation/trip_details_screen_test.dart`

**Consumes:** `AmenityIconsRow(features:)`, `AmenityChip`, `featureLabel`

- [ ] **Step 1: Update `trip_card.dart`**

Replace:

```dart
AmenityIconsRow(amenities: trip.amenities),
```

with:

```dart
AmenityIconsRow(features: trip.features),
```

- [ ] **Step 2: Update trip details header + sheet**

- Import `feature_label.dart` and `bus_feature.dart` as needed.
- Only wrap the amenities `InkWell` when `trip.features.isNotEmpty`:

```dart
if (trip.features.isNotEmpty)
  InkWell(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    onTap: () => _showAmenitiesSheet(context, l10n),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmenityIconsRow(features: trip.features),
        const Icon(
          PhosphorIconsLight.caretDown,
          size: 16,
          color: AppColors.textMuted,
        ),
      ],
    ),
  ),
```

- Sheet chips:

```dart
children: trip.features
    .map(
      (f) => AmenityChip(
        feature: f,
        label: featureLabel(l10n, f),
      ),
    )
    .toList(),
```

- Delete private `_amenityLabel` method.

- [ ] **Step 3: Update `_buildTrip` in details test**

```dart
return BusTripSummary(
  // ...existing fields...
  features: const [
    BusFeature(
      id: 'wifi',
      name: 'Wi Fi',
      iconUrl: 'https://example.com/wifi.webp',
    ),
  ],
);
```

Update amenity sheet test to still expect `Wi-Fi` (ARB) and `Amenities`.

Add:

```dart
testWidgets('hides amenities chrome when features empty', (tester) async {
  final trip = _buildTrip().copyWith(features: const []);
  await _pumpDetails(tester, trip);
  expect(find.byIcon(PhosphorIconsLight.caretDown), findsNothing);
});
```

(Ensure coach / other carets are not false positives — if another caret exists
on the screen, find amenities via a more specific finder such as
`find.descendant` of the ticket header, or assert `Amenities` sheet cannot
open. Prefer asserting no `AmenityIconsRow` via `find.byType(AmenityIconsRow)`
when empty.)

Preferred empty assertion:

```dart
expect(find.byType(AmenityIconsRow), findsNothing);
```

(When empty, row returns `SizedBox.shrink` but the widget still builds if
parent always inserts it — after Step 2 the parent omits the `InkWell`, so
`AmenityIconsRow` is absent. Good.)

- [ ] **Step 4: Run focused tests**

```bash
flutter test \
  test/features/bus/data/bus_dto_mapper_test.dart \
  test/features/bus/presentation/widgets/feature_label_test.dart \
  test/features/bus/presentation/trip_details_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Project analyze on touched paths**

```bash
dart analyze lib/features/bus
```

Expected: No issues.

---

## Spec coverage self-check

| Spec requirement | Task |
|---|---|
| `BusFeature` Freezed entity | 1 |
| Replace amenities / remove placeholders | 1 |
| Mapper `features[]` + skip invalid | 2 |
| Empty → `[]` | 2 |
| `mergeEnrichment` features | 1 |
| Network icon + Phosphor fallback | 4 |
| Localize known ids + ARB dvd/gps | 3 |
| Trip card icons (max 4) | 4–5 |
| Details row + sheet; hide when empty | 5 |
| Tests listed in spec | 1–5 |

## Placeholder / consistency scan

- No TBD/TODO steps.
- Names consistent: `features`, `BusFeature`, `featureLabel`, `FeatureIcon`,
  `AmenityIconsRow(features:)`, `AmenityChip(feature:, label:)`.
