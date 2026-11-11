import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/main.dart';

import 'test_fonts.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

/// Tests normally draw text with a placeholder font whose letters are far
/// wider than real ones, which causes fake overflow errors. Load the real
/// Roboto from the Flutter SDK so layout is checked the way a phone shows it.
Future<void> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir =
      '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto';
  final files = [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
  ].map((f) => File('$dir/$f')).where((f) => f.existsSync()).toList();
  if (files.isEmpty) return;
  final loader = FontLoader('Roboto');
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    await loadAppFonts();
  });

  for (final cfg in const [
    (name: 'normal phone', w: 412.0, h: 915.0, scale: 1.0),
    (name: 'small phone, large fonts', w: 360.0, h: 640.0, scale: 1.3),
  ]) {
    testWidgets('full seller flow on ${cfg.name}', (t) async {
      t.view.physicalSize = Size(cfg.w * 2.625, cfg.h * 2.625);
      t.view.devicePixelRatio = 2.625;
      t.platformDispatcher.textScaleFactorTestValue = cfg.scale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await runFlow(t);
    });
  }
}

/// Scrolls the visible page until [f] is on screen, like a user would.
Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(Scaffold).last,
          // The page itself scrolls vertically (a photo strip scrolls sideways).
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ),
        )
        .first;
    await t.scrollUntilVisible(f, 200, scrollable: scrollable);
  }
  // A lazily built list can estimate its length a little short, so scroll
  // twice: the second pass uses the corrected length.
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 100));
  await t.ensureVisible(f);
}

Future<void> runFlow(WidgetTester t) async {
  {
    SharedPreferences.setMockInitialValues({});

    await t.pumpWidget(const A2Z2GoSellerApp());
    await settle(t);

    // ---- phone screen
    expect(find.text('Welcome, seller'), findsOneWidget);
    await t.enterText(find.byType(TextField), '12');
    await t.tap(find.text('Send code'));
    await settle(t);
    expect(find.textContaining('valid mobile number'), findsOneWidget);

    await t.enterText(find.byType(TextField), '0917 123 4567');
    await t.tap(find.text('Send code'));
    await settle(t);

    // ---- OTP screen (demo code is shown on screen)
    expect(find.text('Enter your code'), findsOneWidget);
    final code = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(code.length, 6);
    await t.enterText(
      find.byType(TextField),
      code == '111111' ? '222222' : '111111',
    );
    await settle(t);
    expect(find.textContaining('Wrong code'), findsOneWidget);
    await t.enterText(find.byType(TextField), code);
    await settle(t);

    // ---- profile
    expect(find.text('What is your name?'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Mayari Santos',
    );
    await t.tap(find.text('Continue'));
    await settle(t);

    // ---- empty dashboard: zeros, no fake data
    expect(find.textContaining(', Mayari'), findsOneWidget);
    expect(find.text('Get your shop going'), findsOneWidget);
    expect(find.text('₱0.00'), findsWidgets);

    // ---- add a product
    await t.tap(find.text('Products').last);
    await settle(t);
    expect(find.text('No products yet'), findsOneWidget);
    await t.tap(find.text('Add your first product'));
    await settle(t);
    for (final (label, value) in [
      ('Product name', 'Dishwashing liquid'),
      ('Selling price', '100'),
      ('Your cost', '60'),
      ('Opening stock', '10'),
    ]) {
      final field = find.widgetWithText(TextFormField, label);
      await reveal(t, field);
      await t.enterText(field, value);
    }
    final addBtn = find.widgetWithText(FilledButton, 'Add product');
    // Let the page finish scrolling to the last field, then go to the button.
    await settle(t);
    await reveal(t, addBtn);
    await t.tap(addBtn);
    await settle(t);
    expect(find.text('Dishwashing liquid'), findsOneWidget);
    expect(find.text('10 in stock'), findsOneWidget);

    // ---- create an order
    await t.tap(find.text('Orders').last);
    await settle(t);
    await t.tap(find.text('Create an order'));
    await settle(t);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Name (optional)'),
      'Ana',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Mobile (optional)'),
      '0918 111 2222',
    );
    await t.tap(find.text('Add'));
    await settle(t);
    await t.tap(find.text('Dishwashing liquid').last);
    await settle(t);
    await t.tap(find.byIcon(Icons.add_circle_outline)); // qty 2
    await settle(t);
    await reveal(t, find.text('Create order'));
    await t.tap(find.text('Create order'));
    await settle(t);
    expect(find.textContaining('#1001'), findsOneWidget);

    // ---- open order, run it through to completed
    await t.tap(find.textContaining('#1001'));
    await settle(t);
    for (final label in [
      'Mark as packed',
      'Mark as shipped',
      'Mark as completed',
    ]) {
      await reveal(t, find.text(label));
      await t.tap(find.text(label));
      await settle(t);
    }
    expect(find.text('Record a return'), findsOneWidget);
    await t.pageBack();
    await settle(t);

    // ---- dashboard + analytics show real numbers
    await t.tap(find.text('Home').last);
    await settle(t);
    expect(find.text('₱200.00'), findsWidgets); // sales today
    await t.tap(find.text('Insights').last);
    await settle(t);
    await reveal(t, find.text('Profit statement'));
    expect(find.text('Profit statement'), findsOneWidget);
    expect(find.text('₱80.00'), findsWidgets); // 200 - 2*60 profit

    // ---- my store: loyalty got points (200 / 100 = 2)
    await t.tap(find.text('Me').last);
    await settle(t);
    expect(find.text('2 points outstanding'), findsOneWidget);
    await t.tap(find.text('Loyalty points'));
    await settle(t);
    expect(find.text('Ana'), findsOneWidget);
    await t.pageBack();
    await settle(t);

    // ---- sign out returns to phone screen
    await reveal(t, find.text('Sign out'));
    await t.tap(find.text('Sign out'));
    await settle(t);
    await t.tap(find.text('Sign out').last);
    await settle(t);
    expect(find.text('Welcome, seller'), findsOneWidget);

    // ---- sign back in: existing seller → OTP only → data still there
    await t.enterText(find.byType(TextField), '09171234567');
    await t.tap(find.text('Send code'));
    await settle(t);
    final code2 = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    await t.enterText(find.byType(TextField), code2);
    await settle(t);
    expect(find.textContaining(', Mayari'), findsOneWidget);
    await t.tap(find.text('Products').last);
    await settle(t);
    expect(find.text('Dishwashing liquid'), findsOneWidget);
    expect(find.text('8 in stock'), findsOneWidget);
  }
}
