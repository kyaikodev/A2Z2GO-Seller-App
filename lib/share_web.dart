import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/format.dart';
import 'core/theme.dart';
import 'data/models.dart';
import 'data/sample_data.dart';
import 'data/store.dart';
import 'screens/buyer/buyer_product_screen.dart';
import 'widgets/scope.dart';

/// The sample share page: the buyer preview as a web page, with the app's
/// sample products and made-up comments built in (no server, no database).
/// Build it with `flutter build web -t lib/share_web.dart`.
///
/// The product comes from the link: `...#/product/A2G-FD-001`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In memory only: a visitor changes and saves nothing (and an old visit
  // cannot add the samples a second time).
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.open(
    await SharedPreferences.getInstance(),
    SellerAccount(phone: '', ownerName: 'A2Z2GO', storeName: 'A2Z2GO'),
  );
  store.loadSampleData();
  addSampleComments(store);
  runApp(ShareApp(store: store));
}

/// Made-up comments for three sample products, so the page shows what it is
/// for. They are marked "Sample" and exist only on this web page (the app's own
/// sample data is unchanged). The "original post" links go to a2z2go's real
/// social pages. Real comments will come from the seller's phone later.
void addSampleComments(AppStore store) {
  SocialPost post(
    SocialPlatform platform,
    String url,
    String title,
    List<(String, String)> comments,
  ) => SocialPost(
    id: newId('s'),
    platform: platform,
    url: url,
    title: title,
    comments: [
      for (final c in comments)
        SharedComment(id: newId('c'), author: c.$1, text: c.$2, demo: true),
    ],
  );
  void give(String sku, List<SocialPost> posts) {
    final p = store.products.where((p) => p.sku == sku).firstOrNull;
    if (p == null) return;
    for (final post in posts) {
      // A product that already has a post on that site (the app's sample data
      // has one) gets the comments on it, not a second box for the same site.
      final same = p.posts
          .where((e) => e.platform == post.platform)
          .firstOrNull;
      if (same != null) {
        same.comments.addAll(post.comments);
      } else {
        p.posts = [...p.posts, post];
      }
    }
  }

  const tiktok = 'https://www.tiktok.com/@a2z2go';
  const facebook = 'https://www.facebook.com/A2zzgo';
  const youtube = 'https://www.youtube.com/@A2Z2GO';

  give('A2G-FD-001', [
    post(SocialPlatform.tiktok, tiktok, 'Salmon for the whole family', [
      ('Maria S.', 'Sulit! Ang sarap ng salmon, malambot at hindi malansa.'),
      ('Jun R.', 'Nag-order kami para sa handaan, naubos agad ang tray.'),
      ('Ana C.', 'Mabilis ang delivery po, mainit pa pagdating.'),
      ('Leo T.', 'Paulit-ulit na kaming umoorder dito.'),
      ('Rica L.', 'Sulit ang presyo para sa 8 hanggang 10 tao.'),
    ]),
    post(SocialPlatform.facebook, facebook, 'Party tray of the week', [
      ('Dan C.', 'Legit po ba ito? Planning to order for my mom\'s birthday.'),
      ('Bea O.', 'Yes po legit, nakaorder na kami last week.'),
      ('Joy M.', 'Thank you po, ang sarap talaga!'),
    ]),
    post(SocialPlatform.youtube, youtube, 'Unboxing the salmon tray', [
      ('Mark D.', 'Looks delicious!'),
      ('Liza P.', 'Saan po pwede umorder?'),
    ]),
  ]);
  give('A2G-HH-004', [
    post(SocialPlatform.facebook, facebook, 'Ang bango ng Sakura Blossom', [
      ('Gina F.', 'Ang bango at tumatagal sa damit, legit ang seller!'),
      ('Ben A.', 'Sulit ang 2kg, nakaka-ilang laba ka na.'),
      ('Cora V.', 'Mabilis dumating, maayos ang pagkaka-pack.'),
      ('Nico B.', 'Bibili ulit ako.'),
    ]),
  ]);
  give('A2G-GR-001', [
    post(SocialPlatform.tiktok, tiktok, 'Weekly grocery haul', [
      ('Tess G.', 'Original at sealed, walang dent ang lata.'),
      ('Paolo K.', 'Mura dito kumpara sa supermarket.'),
      ('Mel H.', 'Maganda ang packaging, salamat po!'),
    ]),
  ]);
}

/// The SKU named in a link such as `/product/A2G-FD-001`, or the first sample
/// product when the link names none.
String skuFromLink(String route) {
  final parts = route.split('/').where((p) => p.isNotEmpty).toList();
  return parts.length >= 2 && parts[parts.length - 2] == 'product'
      ? Uri.decodeComponent(parts.last)
      : sampleFirstSku;
}

class ShareApp extends StatelessWidget {
  final AppStore store;
  const ShareApp({super.key, required this.store});

  Product _product(String route) {
    final sku = skuFromLink(route);
    return store.products.firstWhere(
      (p) => p.sku == sku,
      orElse: () => store.products.first,
    );
  }

  Route<void> _route(RouteSettings settings) => MaterialPageRoute(
    settings: settings,
    builder: (_) => BuyerProductScreen(
      productId: _product(settings.name ?? '/').id,
      share: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'A2Z2GO',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // The link's `#/product/<sku>` is the first route; every route shows
        // that product (a link with no product shows the first sample).
        // A thin bar on top, so nobody takes the made-up comments for real ones.
        builder: (context, child) => Column(
          children: [
            const SampleBar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
        onGenerateRoute: _route,
        // Only that one page, not a stack of `/`, `/product`, `/product/<sku>`.
        onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
      ),
    );
  }
}

/// "Sample preview" in the look of the website's own info message (light blue,
/// black 13 px text).
class SampleBar extends StatelessWidget {
  const SampleBar({super.key});

  @override
  Widget build(BuildContext context) {
    // A Material, so the text gets the app's font (and no stray underline).
    return Material(
      color: const Color(0xFFE2F6FE),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: const SafeArea(
          bottom: false,
          child: Text(
            'Sample preview: the comments are made up.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
