import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/screens/buyer/buyer_product_screen.dart';
import 'package:a2z2go_seller/widgets/scope.dart';
import 'package:a2z2go_seller/widgets/social.dart';

import 'test_fonts.dart';

SocialPost post(String id, SocialPlatform platform, String prefix, int n) =>
    SocialPost(
      id: id,
      platform: platform,
      url: 'https://example.com/$id',
      title: '$prefix caption',
      comments: [
        for (var i = 1; i <= n; i++)
          SharedComment(
            id: '$id-$i',
            author: 'User $i',
            text: '$prefix comment $i',
          ),
      ],
    );

void main() {
  setUpAll(loadAppFonts);

  test('posts are grouped by social, in the order they first appear', () {
    final groups = groupByPlatform([
      post('a', SocialPlatform.tiktok, 'tiktok', 1),
      post('b', SocialPlatform.facebook, 'facebook', 1),
      post('c', SocialPlatform.tiktok, 'tiktok', 1),
    ]);
    expect(groups.keys.toList(), [
      SocialPlatform.tiktok,
      SocialPlatform.facebook,
    ]);
    expect(groups[SocialPlatform.tiktok]!.length, 2);
  });

  testWidgets(
    'buyers get a tab per social, 3 comments each, then See all in a sheet',
    (t) async {
      t.view.physicalSize = const Size(900, 6000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await AppStore.open(
        prefs,
        SellerAccount(
          phone: '+639171234567',
          ownerName: 'A',
          storeName: 'Shop',
        ),
      );
      final product = Product(
        id: 'p1',
        sku: 'SKU-1',
        name: 'Bath soap',
        price: 20,
        stock: 5,
        posts: [
          post('t1', SocialPlatform.tiktok, 'tiktok', 7),
          post('f1', SocialPlatform.facebook, 'facebook', 2),
        ],
      );
      store.addProduct(product);

      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            store: store,
            child: BuyerProductScreen(productId: 'p1'),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));

      // one tab per social, side by side, each with its comment count
      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(
        find.text('7'),
        findsNWidgets(2),
      ); // tab count + "Comments 7" heading
      expect(find.text('2'), findsOneWidget);

      // the first tab (TikTok) shows 3 comments and a button for all 7
      expect(find.text('tiktok comment 3'), findsOneWidget);
      expect(find.text('tiktok comment 4'), findsNothing);
      expect(find.text('facebook comment 1'), findsNothing); // other tab
      expect(find.text('See all 7 comments'), findsOneWidget);

      // "See all" opens a list that scrolls by itself
      await t.tap(find.text('See all 7 comments'));
      await t.pumpAndSettle();
      expect(find.text('tiktok comment 7'), findsOneWidget);
      await t.tapAt(const Offset(5, 5)); // close the sheet
      await t.pumpAndSettle();

      // tapping the Facebook tab swaps the content, no scrolling needed
      await t.tap(find.text('Facebook'));
      await t.pumpAndSettle();
      expect(find.text('facebook comment 2'), findsOneWidget);
      expect(find.text('tiktok comment 1'), findsNothing);
      expect(find.textContaining('See all'), findsNothing); // only 2 comments

      // swiping right goes back to TikTok, swiping left goes on to Facebook
      await t.fling(
        find.text('facebook comment 2'),
        const Offset(300, 0),
        1200,
      );
      await t.pumpAndSettle();
      expect(find.text('tiktok comment 1'), findsOneWidget);
      expect(find.text('facebook comment 2'), findsNothing);
      await t.fling(find.text('tiktok comment 1'), const Offset(-300, 0), 1200);
      await t.pumpAndSettle();
      expect(find.text('facebook comment 2'), findsOneWidget);
      // already on the last tab: a further swipe left changes nothing
      await t.fling(
        find.text('facebook comment 2'),
        const Offset(-300, 0),
        1200,
      );
      await t.pumpAndSettle();
      expect(find.text('facebook comment 2'), findsOneWidget);
    },
  );

  testWidgets('buyers: the next social opens by itself after 6 idle seconds', (
    t,
  ) async {
    t.view.physicalSize = const Size(900, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open(
      await SharedPreferences.getInstance(),
      SellerAccount(phone: '+639171234567', ownerName: 'A', storeName: 'Shop'),
    );
    store.addProduct(
      Product(
        id: 'p2',
        sku: 'SKU-2',
        name: 'Soap',
        price: 20,
        stock: 5,
        posts: [
          post('t1', SocialPlatform.tiktok, 'tiktok', 2),
          post('f1', SocialPlatform.facebook, 'facebook', 2),
        ],
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          store: store,
          child: BuyerProductScreen(productId: 'p2'),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('tiktok comment 1'), findsOneWidget);

    // 5 quiet seconds: nothing yet. A touch starts the count again.
    await t.pump(const Duration(seconds: 5));
    expect(find.text('tiktok comment 1'), findsOneWidget);
    await t.tap(find.text('What people are saying'));
    await t.pump(const Duration(seconds: 5));
    expect(find.text('tiktok comment 1'), findsOneWidget);

    // 6 quiet seconds after the touch: Facebook opens, then TikTok again.
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('facebook comment 1'), findsOneWidget);
    await t.pump(const Duration(seconds: 7));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('tiktok comment 1'), findsOneWidget);
  });

  testWidgets('three tabs fit a small phone and none is cut off', (t) async {
    t.view.physicalSize = const Size(320, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open(
      await SharedPreferences.getInstance(),
      SellerAccount(phone: '+639171234567', ownerName: 'A', storeName: 'Shop'),
    );
    store.addProduct(
      Product(
        id: 'p3',
        sku: 'SKU-3',
        name: 'Soap',
        price: 20,
        stock: 5,
        posts: [
          post('f1', SocialPlatform.facebook, 'facebook', 3),
          post('t1', SocialPlatform.tiktok, 'tiktok', 25),
          post('i1', SocialPlatform.instagram, 'instagram', 0),
        ],
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          store: store,
          child: BuyerProductScreen(productId: 'p3'),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    for (final name in ['Facebook', 'TikTok', 'Instagram']) {
      final box = t.getRect(find.text(name));
      expect(
        box.left >= 0 && box.right <= 320,
        isTrue,
        reason: '$name is on screen',
      );
    }
    // a tab with no comments says so instead of staying blank
    await t.tap(find.text('Instagram'));
    await t.pumpAndSettle();
    expect(find.text('No comments added yet'), findsOneWidget);
  });
}
