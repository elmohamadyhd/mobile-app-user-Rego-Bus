import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/shell/presentation/widgets/main_nav_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Widget wrap({
    required int currentIndex,
    required ValueChanged<int> onSelected,
    Locale locale = const Locale('en'),
    ThemeData? theme,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: MainNavBar(
          currentIndex: currentIndex,
          onDestinationSelected: onSelected,
        ),
      ),
    );
  }

  testWidgets('renders all three destination labels', (tester) async {
    await tester.pumpWidget(wrap(currentIndex: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(currentIndex: 0, onSelected: (i) => tapped = i),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    expect(tapped, 2);
  });

  testWidgets('tapping the already-active destination still fires', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(currentIndex: 0, onSelected: (i) => tapped = i),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    expect(tapped, 0);
  });

  testWidgets('active destination exposes selected semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(currentIndex: 1, onSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Tickets')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Home')),
      isSemantics(isSelected: false),
    );

    handle.dispose();
  });

  testWidgets('renders right-to-left with Arabic labels', (tester) async {
    await tester.pumpWidget(
      wrap(
        currentIndex: 0,
        onSelected: (_) {},
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('الرئيسية'))),
        TextDirection.rtl);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await tester.pumpWidget(
      wrap(currentIndex: 0, onSelected: (_) {}, theme: AppTheme.dark()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('does not overflow at large text scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            // Copy the real (sized) MediaQuery and only crank the text scale.
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: Scaffold(
              bottomNavigationBar: MainNavBar(
                currentIndex: 0,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
