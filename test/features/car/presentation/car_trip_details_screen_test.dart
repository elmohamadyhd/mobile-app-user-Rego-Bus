import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/car_trip_details_screen.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

import '../fake_car_repository.dart';

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

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
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
      ],
    );
    addTearDown(container.dispose);

    if (selectSample) {
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
    expect(repo.lastGetTripId, isNull);
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

    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.carTripDetailsRefreshFailed), findsOneWidget);
    expect(find.text('Sky Travel'), findsWidgets);
  });

  testWidgets('shows hard error on 404', (tester) async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException("This record can't be found", statusCode: 404);
    await pumpDetails(tester, repo: repo, isGuest: false);

    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.carTripDetailsNotFound), findsOneWidget);
  });

  testWidgets('continue navigates to confirm when signed in', (tester) async {
    final repo = FakeCarRepository();
    final container = ProviderContainer(
      overrides: [
        carRepositoryProvider.overrideWithValue(repo),
        guestModeProvider.overrideWith(() => _FakeGuestController(false)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(carBookingProvider.notifier).searchQuotes(params);
    container
        .read(carBookingProvider.notifier)
        .selectQuote(FakeCarRepository.sampleQuote);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CarTripDetailsScreen(),
        ),
        GoRoute(
          path: CarRoutes.confirm,
          builder: (context, state) =>
              const Scaffold(body: Text('confirm-screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('confirm-screen'), findsOneWidget);
  });
}
