// Smoke test: boots the real AppState (local mode), logs in as a demo user,
// verifies every main screen builds, and exercises the price-submit + alert data
// flow that the UI sheets drive.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishibondhu/main.dart';
import 'package:krishibondhu/theme.dart';
import 'package:krishibondhu/screen_main.dart';

void main() {
  testWidgets('demo login → all five screens build', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await app.init();

    expect(app.users.length, greaterThanOrEqualTo(3));
    expect(app.users.any((u) => u.cred == 'rosni'), true);
    expect(app.users.any((u) => u.cred == 'mehedi'), true);
    expect(app.users.any((u) => u.cred == 'nafisa'), true);

    app.demoLogin('rosni');
    expect(app.currentUser?.name, 'Rosni Akter');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: app,
          builder: (_, child) => const Shell(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.textContaining('Rosni'), findsWidgets); // Home greeting

    await tester.tap(
      find.text('Weather').last,
    ); // bottom-nav tab (also appears as a quick action)
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Weather & advisory'), findsOneWidget);

    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Market prices'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Smart reminders'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Rosni Akter'), findsWidgets);
  });

  test(
    'submitting a price is reflected in the market list (sheet data flow)',
    () async {
      SharedPreferences.setMockInitialValues({});
      await app.init();
      app.demoLogin('mehedi'); // trader submits

      final before = app
          .marketsWithPrice('rice', 100)
          .where((m) => m.market.id == 'c7')
          .length;
      await app.submitPrice(cropId: 'rice', marketId: 'c7', price: 77);
      final row = app
          .marketsWithPrice('rice', 100)
          .firstWhere((m) => m.market.id == 'c7');
      expect(row.latest?.price, 77);
      expect(row.latest?.by, 'Mehedi');
      expect(before, isNotNull);
    },
  );

  test('target price triggers price alerts, then de-duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    await app.init();
    app.demoLogin('rosni');
    app.resetAlerts();
    // rosni seeds targets rice:55 and chili:215, both met by fresh prices.
    // checkPriceAlerts returns one un-alerted match per call.
    expect(app.checkPriceAlerts(), isNotNull); // first target
    expect(app.checkPriceAlerts(), isNotNull); // second target
    expect(app.checkPriceAlerts(), isNull); // both alerted → no repeat
  });
}
