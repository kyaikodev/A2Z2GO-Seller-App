import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/screens/buyer/buyer_product_screen.dart';
import 'package:a2z2go_seller/widgets/product_page.dart';
import 'package:a2z2go_seller/widgets/scope.dart';

import 'test_fonts.dart';

SocialPost post(String id, SocialPlatform platform, int n) => SocialPost(
  id: id,
  platform: platform,
  url: 'https://example.com/$id',
  title: '$id caption',
  comments: [
    for (var i = 1; i <= n; i++)
      SharedComment(id: '$id-$i', author: 'User $i', text: '$id comment $i'),
  ],
);

/// Opens the buyer page on a normal phone, so the comments are below the fold.
Future<void> open(
  WidgetTester t,
  List<SocialPost> posts, {
  Random? random,
}) async {
  t.view.physicalSize = const Size(375 * 2, 812 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = await AppStore.open(
    prefs,
    SellerAccount(phone: '+639171234567', ownerName: 'A', storeName: 'Shop'),
  );
  store.addProduct(
    Product(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Bath soap',
      price: 20,
      stock: 5,
      posts: posts,
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        store: store,
        child: BuyerProductScreen(productId: 'p1', random: random),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
}

/// The comment text now shown in the strip.
String shown(WidgetTester t) {
  final f = find.descendant(
    of: find.byType(CommentsPeek),
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(' comment '),
    ),
  );
  expect(f, findsOneWidget);
  return (t.widget(f) as Text).data!;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a strip above the bottom bar gives a glimpse of the comments', (
    t,
  ) async {
    await open(t, [
      post('tt', SocialPlatform.tiktok, 4),
      post('fb', SocialPlatform.facebook, 2),
    ]);
    expect(find.byType(CommentsPeek), findsOneWidget);
    // The strip is a slim bar, not a block that takes over the screen.
    expect(t.getSize(find.byType(CommentsPeek)).height, lessThan(90));
    expect(find.text('See all (6)'), findsOneWidget);
    expect(shown(t), matches(RegExp(r'^(tt|fb) comment \d$')));

    // Tapping it scrolls down to the comments, and the strip steps aside.
    await t.tap(find.byType(CommentsPeek));
    // A scroll animation starts on one frame and runs on the next ones.
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(CommentsPeek), findsNothing);
    expect(find.text('tt comment 1'), findsOneWidget);
  });

  testWidgets('the strip shows another comment every 6 seconds, shuffled', (
    t,
  ) async {
    await open(t, [
      post('tt', SocialPlatform.tiktok, 4),
      post('fb', SocialPlatform.facebook, 2),
    ], random: Random(7));

    final seen = <String>[shown(t)];
    await t.pump(const Duration(seconds: 5));
    expect(shown(t), seen.first, reason: 'it must not change before 6 seconds');

    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(seconds: 1)); // the 6 second mark
      await t.pump(const Duration(milliseconds: 600)); // the fade
      seen.add(shown(t));
      await t.pump(const Duration(seconds: 5, milliseconds: 400));
    }
    // Six comments, six turns: every comment was shown once, none twice.
    expect(seen.toSet().length, 6, reason: 'seen: $seen');
  });

  testWidgets('a finger on the strip pauses the rotation', (t) async {
    await open(t, [
      post('tt', SocialPlatform.tiktok, 4),
      post('fb', SocialPlatform.facebook, 2),
    ], random: Random(7));
    final first = shown(t);
    final g = await t.startGesture(t.getCenter(find.byType(CommentsPeek)));
    await t.pump(const Duration(seconds: 13));
    expect(shown(t), first, reason: 'held: it must stay on the same comment');
    await g.cancel();
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 600));
    expect(shown(t), isNot(first), reason: 'let go: it moves on');
  });

  testWidgets('with reduced motion on, the strip does not rotate', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(t, [
      post('tt', SocialPlatform.tiktok, 4),
      post('fb', SocialPlatform.facebook, 2),
    ]);
    final first = shown(t);
    await t.pump(const Duration(seconds: 19));
    expect(shown(t), first);
  });

  testWidgets('one comment says "comment" and does not rotate', (t) async {
    await open(t, [post('yt', SocialPlatform.youtube, 1)]);
    expect(find.text('See all (1)'), findsOneWidget);
    final first = shown(t);
    await t.pump(const Duration(seconds: 13));
    expect(shown(t), first);
  });

  testWidgets('a product with no comments shows no strip', (t) async {
    await open(t, []);
    expect(find.byType(CommentsPeek), findsNothing);
  });
}
