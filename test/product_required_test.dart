import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/screens/products/product_detail_screen.dart';
import 'package:a2z2go_seller/screens/products/product_form_screen.dart';
import 'package:a2z2go_seller/widgets/scope.dart';

import 'test_fonts.dart';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore.open(
    await SharedPreferences.getInstance(),
    SellerAccount(phone: '+639171234567', ownerName: 'A', storeName: 'Shop'),
  );
}

Widget _app(AppStore store, Widget home) => MaterialApp(
  theme: buildTheme(),
  home: StoreScope(store: store, child: home),
);

void main() {
  setUpAll(loadAppFonts);

  test(
    'a product needs a photo and a real description before it is shared',
    () {
      final p = Product(id: 'p', sku: 'S', name: 'Soap', price: 10);
      expect(p.readyForBuyers, isFalse);
      expect(p.missingForBuyers.length, 2);

      p.description = 'Too short';
      p.images.add('asset:assets/sample/A2G-HH-004.jpg');
      expect(p.missingForBuyers, [
        'a description (at least $minDescriptionLength letters)',
      ]);

      p.description = 'A gentle antibacterial soap for the whole family.';
      expect(p.readyForBuyers, isTrue);
    },
  );

  testWidgets('saving with required fields empty shows them in red', (t) async {
    t.view.physicalSize = const Size(
      540,
      3600,
    ); // tall: every field is on screen
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = await _store();
    await t.pumpWidget(_app(store, const ProductFormScreen()));
    await t.pumpAndSettle();

    // Every required label carries the red star; optional ones say so.
    expect(find.text('Product name *'), findsOneWidget);
    expect(find.text('Category *'), findsOneWidget);
    expect(find.text('Brand (optional)'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'Add product'));
    await t.pumpAndSettle();

    // The first missing field is the name, at the top and in view.
    expect(find.text('Product name is required'), findsOneWidget);
    expect(t.getRect(find.text('Product name is required')).top >= 0, isTrue);
    expect(store.products, isEmpty); // nothing was saved
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('a missing field far below the screen is still caught', (
    t,
  ) async {
    t.view.physicalSize = const Size(540, 700); // very short screen
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = await _store();
    await t.pumpWidget(_app(store, const ProductFormScreen()));
    await t.pumpAndSettle();

    // fill in the name only: the category, price and others stay empty
    final name = find.widgetWithText(
      TextFormField,
      'Product name *',
      skipOffstage: false,
    );
    await t.ensureVisible(name);
    await t.pumpAndSettle();
    await t.enterText(name, 'Soap');
    await t.tap(find.widgetWithText(FilledButton, 'Add product'));
    await t.pumpAndSettle();

    expect(store.products, isEmpty); // nothing was saved
    // the screen scrolled to the first missing field (the category) ...
    expect(find.text('Pick a category, or add a new one.'), findsOneWidget);
    // ... and fields far below were checked too, even though off screen
    expect(find.text('Enter an amount', skipOffstage: false), findsWidgets);
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('the share row waits until the product is ready', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = await _store();
    store.addProduct(
      Product(id: 'p1', sku: 'S1', name: 'Soap', price: 20, stock: 5),
    );
    await t.pumpWidget(_app(store, const ProductDetailScreen(productId: 'p1')));
    await t.pumpAndSettle();

    expect(
      find.textContaining('Needs a photo and a description (at least'),
      findsOneWidget,
    );
    await t.tap(find.text('Share and preview'));
    await t.pump();
    expect(find.textContaining('first. Tap Edit.'), findsOneWidget);
    await t.pump(const Duration(seconds: 10)); // let the message go away
  });

  testWidgets('a long description folds to three lines with Read more', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = await _store();
    final long = List.filled(
      30,
      'Shield is a gentle antibacterial soap.',
    ).join(' ');
    store.addProduct(
      Product(
        id: 'p9',
        sku: 'S9',
        name: 'Soap',
        price: 20,
        stock: 5,
        description: long,
      ),
    );
    await t.pumpWidget(_app(store, const ProductDetailScreen(productId: 'p9')));
    await t.pumpAndSettle();

    final text = find.text(long);
    double height() => t.getSize(text).height;
    final folded = height();
    expect(find.text('Read more'), findsOneWidget);
    // a cost of zero is shown as not set, not as a 100% margin
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    await t.tap(find.text('Read more'));
    await t.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(height() > folded * 2, isTrue); // the whole text is now shown

    await t.tap(find.text('Show less'));
    await t.pumpAndSettle();
    expect(height(), folded);
  });
}
