import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/main.dart';

import 'test_fonts.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> toCodeScreen(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(const A2Z2GoSellerApp());
  await settle(t);
  await t.enterText(find.byType(TextField), '0917 123 4567');
  await t.tap(find.text('Send code'));
  await settle(t);
  expect(find.text('Enter your code'), findsOneWidget);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('code screen has one way back, not two', (t) async {
    await toCodeScreen(t);
    expect(find.text('Use a different number'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('the right code shows "Code verified", then the next step', (
    t,
  ) async {
    await toCodeScreen(t);
    final code = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    await t.enterText(find.byType(TextField), code);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Code verified'), findsOneWidget);
    await settle(t);
    expect(find.text('What is your name?'), findsOneWidget);
  });

  testWidgets('a wrong code shows the error and empties the boxes', (t) async {
    await toCodeScreen(t);
    final code = t.widget<SelectableText>(find.byType(SelectableText)).data!;
    await t.enterText(
      find.byType(TextField),
      code == '111111' ? '222222' : '111111',
    );
    await settle(t);
    expect(find.textContaining('Wrong code'), findsOneWidget);
    expect(find.text('Code verified'), findsNothing);
    expect(find.text('Enter your code'), findsOneWidget); // still on this step
  });
}
