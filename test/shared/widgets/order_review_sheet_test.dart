import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_review_sheet.dart';

void main() {
  testWidgets('submit disabled until a star is chosen', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOrderReviewSheet(
                context,
                onSubmit: (_, __) async {
                  submitted = true;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Submit review'), findsOneWidget);
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
  });

  testWidgets('submit calls onSubmit with rating and trimmed comment', (
    tester,
  ) async {
    int? gotRating;
    String? gotComment;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOrderReviewSheet(
                context,
                onSubmit: (rating, comment) async {
                  gotRating = rating;
                  gotComment = comment;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('order-review-star-5')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  great  ');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(gotRating, 5);
    expect(gotComment, 'great');
  });
}
