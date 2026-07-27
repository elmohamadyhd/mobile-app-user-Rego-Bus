import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip_filters.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_filter_button.dart';
import 'package:safaria/l10n/app_localizations.dart';

void main() {
  group('BookingAppBar', () {
    testWidgets('invokes onBack instead of popping when provided',
        (tester) async {
      var backTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BookingAppBar(
            title: 'Title',
            onBack: () => backTapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(backTapped, isTrue);
    });

    testWidgets('insets trailing action from screen edge', (tester) async {
      const actionKey = Key('trailing-action');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: BookingAppBar(
              title: 'Title',
              action: SizedBox(
                key: actionKey,
                width: 48,
                height: 48,
              ),
            ),
          ),
        ),
      );

      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      final actionRight = tester.getTopRight(find.byKey(actionKey)).dx;

      // The bar insets its row by AppSpacing.xs, then the action by a further
      // AppSpacing.xs at the end. What this guards is the regression that
      // padding was added to fix: before the action had any inset of its own
      // it sat flush against the screen edge.
      expect(
        screenWidth - actionRight,
        greaterThanOrEqualTo(AppSpacing.xs * 2),
      );
    });

    testWidgets('badge is not clipped above app bar bounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            appBar: BookingAppBar(
              title: 'Title',
              action: TripFilterButton(
                filters: const BusTripFilters(operators: {'Go Bus'}),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final appBarBox =
          tester.renderObject<RenderBox>(find.byType(BookingAppBar));
      final badgeBox = tester.renderObject<RenderBox>(find.text('1'));
      final appBarTop = appBarBox.localToGlobal(Offset.zero).dy;
      final badgeTop = badgeBox.localToGlobal(Offset.zero).dy;

      expect(badgeTop, greaterThanOrEqualTo(appBarTop));
    });

    testWidgets('does not overflow with long route title and subtitle',
        (tester) async {
      // Reproduce the phone width from the production overflow report.
      tester.view.physicalSize = const Size(411, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longTitle = 'WJH3+W2، الظهير الصحراوى لمحافظة ال، محافظة '
          '4802001، مصر → طريق الجيش، سان ستفانو، El Raml 2، '
          'محافظة الإسكندرية 5452054، مصر';

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          home: Scaffold(
            appBar: BookingAppBar(
              title: longTitle,
              subtitle: '31 يوليو',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final titleText = tester.widget<Text>(find.text(longTitle));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });
  });

  group('TripFilterButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      required BusTripFilters filters,
      VoidCallback? onTap,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Center(
              child: TripFilterButton(
                filters: filters,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('meets minimum 48dp touch target', (tester) async {
      await pumpButton(tester, filters: const BusTripFilters());

      final size = tester.getSize(find.byType(TripFilterButton));
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    testWidgets('shows badge when filters are active', (tester) async {
      await pumpButton(
        tester,
        filters: const BusTripFilters(operators: {'Go Bus'}),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('invokes onTap when pressed', (tester) async {
      var tapped = false;

      await pumpButton(
        tester,
        filters: const BusTripFilters(),
        onTap: () => tapped = true,
      );

      await tester.tap(find.byIcon(AppIcons.filter));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
