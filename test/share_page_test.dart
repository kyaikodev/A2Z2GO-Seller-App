import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/sample_data.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/screens/buyer/buyer_product_screen.dart';
import 'package:a2z2go_seller/share_web.dart';
import 'package:a2z2go_seller/widgets/scope.dart';

import 'test_fonts.dart';

Future<AppStore> sampleStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.open(
    await SharedPreferences.getInstance(),
    SellerAccount(phone: '', ownerName: 'A2Z2GO', storeName: 'A2Z2GO'),
  );
  store.loadSampleData();
  addSampleComments(store);
  return store;
}

void main() {
  setUpAll(loadAppFonts);

  test('the link names the product, or falls back to the first sample', () {
    expect(skuFromLink('/product/A2G-HH-004'), 'A2G-HH-004');
    expect(skuFromLink('/product/A2G%2DHH%2D004'), 'A2G-HH-004');
    expect(skuFromLink('/'), sampleFirstSku);
    expect(skuFromLink(''), sampleFirstSku);
    expect(skuFromLink('/something/else'), sampleFirstSku);
  });

  // A plain test, not a widget test: the store saves with a timer, and this
  // test never lets time pass.
  test(
    'the sample comments exist, are marked Sample, and only on three products',
    () async {
      final store = await sampleStore();
      final withComments = store.products.where((p) => p.commentCount > 0);
      expect(withComments.map((p) => p.sku).toSet(), {
        'A2G-FD-001',
        'A2G-HH-004',
        'A2G-GR-001',
      });
      for (final p in withComments) {
        for (final post in p.posts) {
          expect(post.comments.every((c) => c.demo), isTrue);
        }
      }
    },
  );

  testWidgets(
    'the shared page opens the real product on the website, and shows no preview note',
    (t) async {
      t.view.physicalSize = const Size(375 * 2, 812 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final store = await sampleStore();
      final product = store.products.firstWhere((p) => p.sku == 'A2G-FD-001');
      final opened = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            store: store,
            child: BuyerProductScreen(
              productId: product.id,
              share: true,
              onOpenWebsite: (_, url) => opened.add(url),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));

      // The seller's "how buyers will see it" note is not shown to buyers.
      expect(
        find.text('This is how buyers will see your product.'),
        findsNothing,
      );

      // The "Home" link and Add To Cart both leave for the website.
      await t.tap(find.text('Home'));
      await t.pump();
      await t.ensureVisible(find.text('Add To Cart'));
      await t.tap(find.text('Add To Cart'));
      await t.pump();
      expect(opened, [product.sourceUrl, product.sourceUrl]);
      // ...and none of them shows the seller's "not connected yet" message.
      expect(find.text('The cart is coming soon.'), findsNothing);
      expect(
        find.text('This is a preview. It is not connected yet.'),
        findsNothing,
      );
    },
  );

  testWidgets('the seller preview still says it is a preview', (t) async {
    t.view.physicalSize = const Size(375 * 2, 812 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = await sampleStore();
    final product = store.products.firstWhere((p) => p.sku == 'A2G-FD-001');
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          store: store,
          child: BuyerProductScreen(productId: product.id),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.text('This is how buyers will see your product.'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('Add To Cart'));
    await t.tap(find.text('Add To Cart'));
    await t.pump();
    expect(find.text('The cart is coming soon.'), findsOneWidget);
  });
}
