import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/format.dart';

import 'test_fonts.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/auth.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/screens/analytics/analytics_screen.dart';
import 'package:a2z2go_seller/screens/dashboard/dashboard_screen.dart';
import 'package:a2z2go_seller/screens/orders/order_detail_screen.dart';
import 'package:a2z2go_seller/screens/orders/order_form_screen.dart';
import 'package:a2z2go_seller/screens/orders/orders_screen.dart';
import 'package:a2z2go_seller/screens/orders/return_detail_screen.dart';
import 'package:a2z2go_seller/screens/orders/return_form_screen.dart';
import 'package:a2z2go_seller/screens/products/product_detail_screen.dart';
import 'package:a2z2go_seller/screens/buyer/buyer_product_screen.dart';
import 'package:a2z2go_seller/screens/products/product_form_screen.dart';
import 'package:a2z2go_seller/screens/products/import_comments_screen.dart';
import 'package:a2z2go_seller/screens/products/proof_screen.dart';
import 'package:a2z2go_seller/screens/products/products_screen.dart';
import 'package:a2z2go_seller/screens/store/expenses_screen.dart';
import 'package:a2z2go_seller/screens/store/loyalty_screen.dart';
import 'package:a2z2go_seller/screens/store/my_store_screen.dart';
import 'package:a2z2go_seller/widgets/scope.dart';

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

/// A store with a realistic spread of data, including long names.
Future<(AppStore, AuthController)> seeded() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthController.create();
  final s = await AppStore.open(
    prefs,
    SellerAccount(
      phone: '+639171234567',
      ownerName: 'Mayari Dela Cruz-Santos',
      storeName: 'Mayari Sari-Sari Store and General Merchandise',
    ),
  );
  Product add(String n, double price, double cost, int stock) {
    final p = Product(
      id: newId('p'),
      sku: s.nextSku(),
      name: n,
      category: 'Household essentials',
      price: price,
      cost: cost,
      stock: stock,
      description:
          'A long description that should wrap across several lines '
          'without breaking the layout on a narrow phone screen.',
    );
    s.addProduct(p);
    return p;
  }

  final a = add(
    'Extra long product name for dishwashing liquid 500ml lemon',
    1250.5,
    800,
    40,
  );
  final b = add('Soap', 45, 30, 3);
  add('Out of stock item', 99, 50, 0);
  s.createOrder(
    customerName: 'Maria Clara Magdalena Santos',
    customerPhone: '+639170000001',
    lines: {a: 5, b: 1},
    discount: 100,
    payment: 'Bank transfer',
    note: 'Please deliver after 5pm and ring the bell twice.',
  );
  final done = s.orders.first;
  while (done.status.next != null) {
    s.advanceOrder(done);
  }
  s.createOrder(
    customerName: '',
    customerPhone: '',
    lines: {a: 2},
    discount: 0,
    payment: 'Cash',
    note: '',
  );
  s.createReturn(
    order: done,
    qtys: {done.items.first: 2},
    reason: 'Not as described',
    note: 'Box was open',
    refund: 2400,
    restock: true,
  );
  s.addExpense(
    Expense(
      id: newId('e'),
      title: 'Packaging tape, boxes and bubble wrap',
      category: 'Shipping & packaging',
      amount: 1234.5,
    ),
  );
  s.addCustomerPoints('+639170000009', 'Jo', 120, 'Promo');
  return (s, auth);
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    await loadAppFonts();
  });

  Future<void> show(
    WidgetTester t,
    AppStore s,
    AuthController auth,
    Widget screen,
  ) async {
    await t.pumpWidget(
      AuthScope(
        auth: auth,
        child: StoreScope(
          store: s,
          child: MaterialApp(theme: buildTheme(), home: screen),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  for (final cfg in const [
    (name: 'normal', w: 412.0, h: 915.0, scale: 1.0),
    (name: 'small + large fonts', w: 360.0, h: 640.0, scale: 1.3),
    (name: 'tiny + largest fonts', w: 320.0, h: 568.0, scale: 1.6),
  ]) {
    testWidgets('every screen lays out cleanly: ${cfg.name}', (t) async {
      t.view.physicalSize = Size(cfg.w * 2, cfg.h * 2);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = cfg.scale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

      final (s, auth) = await seeded();
      final product = s.products.first;
      final completed = s.orders.firstWhere(
        (o) => o.status == OrderStatus.completed,
      );
      final open = s.orders.firstWhere((o) => o.status.isOpen);
      final ret = s.returns.first;
      final customer = s.loyaltyCustomers.first;

      // Long text and several photos and comments, the way real sellers will.
      product
        ..images = ['https://example.com/a.png', 'https://example.com/b.png']
        ..brand = 'Pride'
        ..sourceUrl = 'https://a2z2go.com/catalog/product/view/id/8691/s/a-very-long-product-name/'
        ..description =
            'Laundry powder with fabric conditioner in a Sakura Blossom scent. ' *
            4;
      product.posts.add(
        SocialPost(
          id: 's1',
          platform: SocialPlatform.facebook,
          url: 'https://www.facebook.com/PridePHL/posts/ang-blooming-na-bango-ng-sakura-blossom-nasa-pride-with-fabric-conditioner-na-ma/2856609677687109/',
          title:
              'Ang blooming na bango ng Sakura Blossom, nasa Pride with Fabric Conditioner na! ' *
              3,
          thumbUrl: 'https://example.com/t.jpg',
          comments: [
            for (var i = 0; i < 5; i++)
              SharedComment(
                id: 'c',
                author: 'A customer with a rather long display name ',
                text:
                    'Ang bango talaga at tumatagal pa sa damit, legit ang seller! ' *
                    2,
                demo: i.isEven,
              ),
          ],
        ),
      );
      s.updateProduct(product);

      final screens = <String, Widget>{
        'dashboard': DashboardScreen(onGoTab: (_) {}, onGoOrders: (_) {}),
        'products': const ProductsScreen(),
        'product detail': ProductDetailScreen(productId: product.id),
        'product form (add)': const ProductFormScreen(),
        'product form (edit)': ProductFormScreen(productId: product.id),
        'orders': const OrdersScreen(),
        'order form': const OrderFormScreen(),
        'order detail (completed)': OrderDetailScreen(orderId: completed.id),
        'order detail (open)': OrderDetailScreen(orderId: open.id),
        'return form': ReturnFormScreen(orderId: completed.id),
        'return detail': ReturnDetailScreen(returnId: ret.id),
        'analytics': const AnalyticsScreen(),
        'expenses': const ExpensesScreen(),
        'loyalty': const LoyaltyScreen(),
        'loyalty customer': LoyaltyCustomerScreen(phone: customer.phone),
        'my store': const MyStoreScreen(),
        'social proof': ProofScreen(productId: product.id),
        'add comments': ImportCommentsScreen(
          post: product.posts.first,
          onChanged: () {},
        ),
        'buyer view': BuyerProductScreen(productId: product.id),
      };

      for (final e in screens.entries) {
        await show(t, s, auth, e.value);
        // Scroll to the bottom so lazily-built lower sections are laid out too.
        final scrollables = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.vertical,
        );
        if (scrollables.evaluate().isNotEmpty) {
          for (var i = 0; i < 6; i++) {
            await t.drag(
              scrollables.first,
              const Offset(0, -500),
              warnIfMissed: false,
            );
            await t.pump(const Duration(milliseconds: 100));
          }
        }
        final problem = t.takeException();
        if (problem != null) {
          fail('${e.key}: ${problem.toString().split('\n').first}');
        }
        expect(find.byType(Scaffold), findsWidgets, reason: e.key);
      }
    });
  }
}
