import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/format.dart';
import 'package:a2z2go_seller/data/auth.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/reports.dart';
import 'package:a2z2go_seller/data/store.dart';

Future<AppStore> freshStore([SharedPreferences? prefs]) async {
  SharedPreferences.setMockInitialValues({});
  prefs ??= await SharedPreferences.getInstance();
  return AppStore.open(
    prefs,
    SellerAccount(
      phone: '+639171234567',
      ownerName: 'Mayari',
      storeName: 'Sari-Sari',
    ),
  );
}

Product mk(
  AppStore s, {
  String name = 'Soap',
  double price = 100,
  double cost = 60,
  int stock = 10,
}) {
  final p = Product(
    id: newId('p'),
    sku: s.nextSku(),
    name: name,
    price: price,
    cost: cost,
    stock: stock,
  );
  expect(s.addProduct(p).ok, true);
  return p;
}

void main() {
  group('phone', () {
    test('normalizes PH mobile formats', () {
      expect(normalizePhone('0917 123 4567'), '+639171234567');
      expect(normalizePhone('+63 917-123-4567'), '+639171234567');
      expect(normalizePhone('9171234567'), '+639171234567');
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('0817 123 4567'), isNull);
    });
  });

  group('new seller starts empty', () {
    test('no data anywhere', () async {
      final s = await freshStore();
      expect(s.products, isEmpty);
      expect(s.orders, isEmpty);
      final r = Report.build(s, Period.days(7));
      expect(r.netProfit, 0);
      expect(r.netSales, 0);
      expect(r.salesSeries.every((v) => v == 0), true);
    });
  });

  group('products & stock', () {
    test(
      'opening stock creates a history entry; stock out/damaged guard',
      () async {
        final s = await freshStore();
        final p = mk(s, stock: 5);
        expect(s.movesFor(p.id).single.delta, 5);
        expect(s.adjustStock(p, MoveType.stockOut, 9).ok, false);
        expect(s.adjustStock(p, MoveType.stockOut, 2).ok, true);
        expect(p.stock, 3);
        expect(s.adjustStock(p, MoveType.adjust, 8).ok, true);
        expect(p.stock, 8);
        expect(s.adjustStock(p, MoveType.stockIn, 0).ok, false);
      },
    );

    test('duplicate SKU rejected', () async {
      final s = await freshStore();
      final p = mk(s);
      final dup = Product(id: newId('p'), sku: p.sku, name: 'x', price: 1);
      expect(s.addProduct(dup).ok, false);
    });

    test('delete removes product', () async {
      final s = await freshStore();
      final p = mk(s);
      s.deleteProduct(p);
      expect(s.products, isEmpty);
      expect(s.moves, isEmpty);
    });
  });

  group('orders', () {
    test(
      'create reserves stock, blocks overselling, cancel restores',
      () async {
        final s = await freshStore();
        final p = mk(s, stock: 5);
        expect(
          s
              .createOrder(
                customerName: '',
                customerPhone: '',
                lines: {p: 6},
                discount: 0,
                payment: 'Cash',
                note: '',
              )
              .ok,
          false,
        );
        expect(p.stock, 5);
        expect(
          s
              .createOrder(
                customerName: 'A',
                customerPhone: '',
                lines: {p: 3},
                discount: 0,
                payment: 'Cash',
                note: '',
              )
              .ok,
          true,
        );
        expect(p.stock, 2);
        final o = s.orders.single;
        expect(o.number, 1001);
        s.cancelOrder(o);
        expect(p.stock, 5);
        expect(o.status, OrderStatus.cancelled);
        // cancelled orders give no sales
        expect(Report.build(s, Period.days(7)).netSales, 0);
      },
    );

    test('discount cannot exceed subtotal', () async {
      final s = await freshStore();
      final p = mk(s);
      expect(
        s
            .createOrder(
              customerName: '',
              customerPhone: '',
              lines: {p: 1},
              discount: 101,
              payment: 'Cash',
              note: '',
            )
            .ok,
        false,
      );
    });

    test('completed order feeds sales & profit with real numbers', () async {
      final s = await freshStore();
      final p = mk(s, price: 100, cost: 60, stock: 10);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 4},
        discount: 20,
        payment: 'GCash',
        note: '',
      );
      final o = s.orders.single;
      // not completed yet → no sales
      expect(Report.build(s, Period.days(7)).netSales, 0);
      while (o.status.next != null) {
        s.advanceOrder(o);
      }
      expect(o.status, OrderStatus.completed);
      final r = Report.build(s, Period.days(7));
      expect(r.gross, 400);
      expect(r.discounts, 20);
      expect(r.netSales, 380);
      expect(r.cogs, 240);
      expect(r.netProfit, 140);
      expect(r.ordersCompleted, 1);
      expect(r.salesSeries.last, 380); // today is last bucket
      expect(r.profitSeries.last, 140);
      expect(r.bestSellers.single.qty, 4);
    });

    test('expenses and damaged stock reduce profit', () async {
      final s = await freshStore();
      final p = mk(s, price: 100, cost: 60, stock: 10);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 2},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      final o = s.orders.single;
      while (o.status.next != null) {
        s.advanceOrder(o);
      }
      s.addExpense(
        Expense(
          id: newId('e'),
          title: 'Boxes',
          category: 'Supplies',
          amount: 30,
        ),
      );
      s.adjustStock(p, MoveType.damaged, 1, note: 'dropped');
      final r = Report.build(s, Period.days(7));
      expect(r.netSales, 200);
      expect(r.cogs, 120);
      expect(r.expenses, 30);
      expect(r.stockLoss, 60);
      expect(r.netProfit, 200 - 120 - 60 - 30);
    });

    test('deleting an expense updates profit (data is removable)', () async {
      final s = await freshStore();
      final e = Expense(
        id: newId('e'),
        title: 'Rent',
        category: 'Rent & utilities',
        amount: 500,
      );
      s.addExpense(e);
      expect(Report.build(s, Period.days(7)).netProfit, -500);
      s.deleteExpense(e);
      expect(Report.build(s, Period.days(7)).netProfit, 0);
    });

    test('deleting an open order restores stock', () async {
      final s = await freshStore();
      final p = mk(s, stock: 5);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 2},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      s.deleteOrder(s.orders.single);
      expect(p.stock, 5);
      expect(s.orders, isEmpty);
    });

    test('order numbers are not reused after deletion', () async {
      final s = await freshStore();
      final p = mk(s, stock: 5);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 1},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      s.deleteOrder(s.orders.single);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 1},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      expect(s.orders.single.number, 1002);
    });
  });

  group('returns', () {
    Future<(AppStore, Product, Order)> completed() async {
      final s = await freshStore();
      final p = mk(s, price: 100, cost: 60, stock: 10);
      s.createOrder(
        customerName: 'Ana',
        customerPhone: '+639170000001',
        lines: {p: 4},
        discount: 40,
        payment: 'Cash',
        note: '',
      );
      final o = s.orders.single;
      while (o.status.next != null) {
        s.advanceOrder(o);
      }
      return (s, p, o);
    }

    test('only completed orders; quantity limits', () async {
      final s = await freshStore();
      final p = mk(s);
      s.createOrder(
        customerName: '',
        customerPhone: '',
        lines: {p: 2},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      final o = s.orders.single;
      expect(
        s
            .createReturn(
              order: o,
              qtys: {o.items[0]: 1},
              reason: 'x',
              note: '',
              refund: 10,
              restock: true,
            )
            .ok,
        false,
      );

      final (s2, _, o2) = await completed();
      expect(
        s2
            .createReturn(
              order: o2,
              qtys: {o2.items[0]: 5},
              reason: 'x',
              note: '',
              refund: 1,
              restock: true,
            )
            .ok,
        false,
      );
      expect(
        s2
            .createReturn(
              order: o2,
              qtys: {o2.items[0]: 0},
              reason: 'x',
              note: '',
              refund: 1,
              restock: true,
            )
            .ok,
        false,
      );
    });

    test('approve refunds, restocks, reverses points; sales reduce', () async {
      final (s, p, o) = await completed();
      expect(s.balanceOf('+639170000001'), 3); // total 360 / 100
      final suggested = s.suggestedRefund(o, {o.items[0]: 2});
      expect(suggested, 180); // 200 gross * (360/400)
      expect(
        s
            .createReturn(
              order: o,
              qtys: {o.items[0]: 2},
              reason: 'Damaged item',
              note: '',
              refund: suggested,
              restock: true,
            )
            .ok,
        true,
      );
      final r = s.returns.single;
      // requested only: nothing changes yet
      expect(Report.build(s, Period.days(7)).refunds, 0);
      expect(s.returnableQty(o, o.items[0].productId), 2);
      final stockBefore = p.stock;
      s.approveReturn(r);
      expect(p.stock, stockBefore + 2);
      final rep = Report.build(s, Period.days(7));
      expect(rep.refunds, 180);
      expect(rep.netSales, 360 - 180);
      expect(rep.cogs, 240 - 120);
      expect(s.balanceOf('+639170000001'), 3 - 1);
      // cannot approve twice
      s.approveReturn(r);
      expect(p.stock, stockBefore + 2);
    });

    test('rejected return frees quantity and changes nothing', () async {
      final (s, p, o) = await completed();
      s.createReturn(
        order: o,
        qtys: {o.items[0]: 4},
        reason: 'x',
        note: '',
        refund: 50,
        restock: true,
      );
      expect(s.returnableQty(o, o.items[0].productId), 0);
      final stock = p.stock;
      s.rejectReturn(s.returns.single);
      expect(s.returnableQty(o, o.items[0].productId), 4);
      expect(p.stock, stock);
      expect(Report.build(s, Period.days(7)).refunds, 0);
    });

    test(
      'deleting an approved return undoes stock, refund and points',
      () async {
        final (s, p, o) = await completed();
        final stock0 = p.stock;
        s.createReturn(
          order: o,
          qtys: {o.items[0]: 2},
          reason: 'x',
          note: '',
          refund: 180,
          restock: true,
        );
        s.approveReturn(s.returns.single);
        s.deleteReturn(s.returns.single);
        expect(p.stock, stock0);
        expect(Report.build(s, Period.days(7)).refunds, 0);
        expect(s.balanceOf('+639170000001'), 3);
      },
    );
  });

  group('loyalty', () {
    test(
      'earn on completion only, with phone; redeem; no negative balance',
      () async {
        final s = await freshStore();
        final p = mk(s, price: 250, cost: 100, stock: 10);
        s.createOrder(
          customerName: 'Ben',
          customerPhone: '',
          lines: {p: 1},
          discount: 0,
          payment: 'Cash',
          note: '',
        );
        s.createOrder(
          customerName: 'Cy',
          customerPhone: '+639170000002',
          lines: {p: 2},
          discount: 0,
          payment: 'Cash',
          note: '',
        );
        for (final o in s.orders) {
          // pending: no points yet
          expect(s.loyaltyTxns, isEmpty);
          while (o.status.next != null) {
            s.advanceOrder(o);
          }
        }
        final c = s.loyaltyCustomers.single;
        expect(c.phone, '+639170000002');
        expect(c.balance, 5); // 500/100
        expect(s.redeemPoints(c, 6, '').ok, false);
        expect(s.redeemPoints(c, 2, 'free item').ok, true);
        expect(s.balanceOf(c.phone), 3);
        expect(s.adjustPoints(s.loyaltyCustomers.single, -10, '').ok, false);
      },
    );

    test('disabled loyalty awards nothing', () async {
      final s = await freshStore();
      s.loyalty.enabled = false;
      final p = mk(s, price: 500, stock: 3);
      s.createOrder(
        customerName: 'x',
        customerPhone: '+639170000003',
        lines: {p: 1},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      final o = s.orders.single;
      while (o.status.next != null) {
        s.advanceOrder(o);
      }
      expect(s.loyaltyTxns, isEmpty);
    });
  });

  group('persistence', () {
    test('data survives closing the app, per account', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final acct = SellerAccount(
        phone: '+639171234567',
        ownerName: 'M',
        storeName: 'S',
      );
      final s1 = await AppStore.open(prefs, acct);
      final p = mk(s1, name: 'Persisted', price: 55, stock: 7);
      s1.createOrder(
        customerName: 'Z',
        customerPhone: '',
        lines: {p: 2},
        discount: 5,
        payment: 'Maya',
        note: 'hi',
      );
      s1.addExpense(
        Expense(
          id: newId('e'),
          title: 'Ads',
          category: 'Advertising',
          amount: 99,
        ),
      );
      await s1.flush();

      final s2 = await AppStore.open(prefs, acct);
      expect(s2.products.single.name, 'Persisted');
      expect(s2.products.single.stock, 5);
      expect(s2.orders.single.discount, 5);
      expect(s2.orders.single.items.single.qty, 2);
      expect(s2.expenses.single.amount, 99);
      expect(s2.moves.length, s1.moves.length);

      // another seller on the same phone sees nothing
      final other = await AppStore.open(
        prefs,
        SellerAccount(phone: '+639179999999', ownerName: 'O', storeName: 'O'),
      );
      expect(other.products, isEmpty);

      // erase all really empties and persists
      s2.eraseAllData();
      await s2.flush();
      final s3 = await AppStore.open(prefs, acct);
      expect(s3.products, isEmpty);
      expect(s3.orders, isEmpty);
    });
  });

  group('sample data', () {
    test(
      'loads a consistent demo shop once; edits stick after restart',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final acct = SellerAccount(
          phone: '+639171234567',
          ownerName: 'Mayari',
          storeName: 'Shop',
        );
        final s = await AppStore.open(prefs, acct);
        expect(s.loadSampleData().ok, true);

        expect(s.products.length, 20);
        expect(s.products.every((p) => p.stock >= 0), true);
        expect(s.orders.length, 17);
        for (final st in OrderStatus.values) {
          expect(s.orders.any((o) => o.status == st), true, reason: st.name);
        }
        expect(
          s.returns.where((r) => r.status == ReturnStatus.requested).length,
          1,
        );
        expect(s.expenses.isNotEmpty, true);
        final salmon = s.products.firstWhere((p) => p.sku == 'A2G-FD-001');
        expect(salmon.price, 2840);
        expect(Report.build(s, Period.days(7)).netSales > 0, true);

        // a second tap is refused and adds nothing
        expect(s.loadSampleData().ok, false);
        expect(s.products.length, 20);

        // delete + edit, then reopen: nothing comes back or resets
        s.deleteProduct(s.products.firstWhere((p) => p.sku == 'A2G-GR-003'));
        salmon.name = 'Salmon (edited)';
        s.updateProduct(salmon);
        await Future<void>.delayed(Duration.zero);
        final s2 = await AppStore.open(prefs, acct);
        expect(s2.products.length, 19);
        expect(s2.products.any((p) => p.sku == 'A2G-GR-003'), false);
        expect(s2.products.any((p) => p.name == 'Salmon (edited)'), true);
      },
    );
  });

  group('auth + otp', () {
    Future<AuthController> auth() async {
      SharedPreferences.setMockInitialValues({});
      return AuthController.create();
    }

    test('invalid phone rejected', () async {
      final a = await auth();
      expect(await a.requestOtp('123'), isNotNull);
      expect(a.challenge, isNull);
    });

    test('new seller: otp → profile → signed in; sign out → sign in again w/o profile', () async {
      final a = await auth();
      expect(a.stage, AuthStage.signedOut);
      expect(await a.requestOtp('0917 123 4567'), isNull);
      final code = a.challenge!.code;
      expect(code.length, 6);
      expect(
        await a.verifyOtp('000000' == code ? '111111' : '000000'),
        contains('Wrong code'),
      );
      expect(await a.verifyOtp(code), isNull);
      expect(a.needsProfile, true);
      expect(a.stage, AuthStage.signedOut);
      await a.completeProfile(ownerName: 'Mayari', storeName: 'Sari-Sari');
      expect(a.stage, AuthStage.signedIn);
      expect(a.current!.phone, '+639171234567');

      // session survives an app restart
      final prefs = a.prefs;
      final again = AuthController(prefs)..challenge = null;
      // recreate via restore path
      final restored = await AuthController.create();
      expect(restored.stage, AuthStage.signedIn);
      expect(again.stage, AuthStage.loading);

      await a.signOut();
      expect(a.stage, AuthStage.signedOut);
      final restored2 = await AuthController.create();
      expect(restored2.stage, AuthStage.signedOut);

      // existing seller signs back in with OTP only
      expect(await a.requestOtp('09171234567'), isNull);
      expect(await a.verifyOtp(a.challenge!.code), isNull);
      expect(a.needsProfile, false);
      expect(a.stage, AuthStage.signedIn);
      expect(a.current!.storeName, 'Sari-Sari');
    });

    test('five wrong tries invalidate the code; resend is throttled', () async {
      final a = await auth();
      await a.requestOtp('09171234567');
      final code = a.challenge!.code;
      final wrong = code == '123456' ? '654321' : '123456';
      for (var i = 0; i < 4; i++) {
        expect(await a.verifyOtp(wrong), contains('Wrong code'));
      }
      expect(await a.verifyOtp(wrong), contains('Too many'));
      expect(a.challenge, isNull);
      expect(await a.verifyOtp(code), isNotNull); // old code is dead

      expect(await a.requestOtp('09171234567'), isNull);
      expect(await a.requestOtp('09171234567'), contains('wait'));
    });

    test('delete account removes account and data', () async {
      final a = await auth();
      await a.requestOtp('09171234567');
      await a.verifyOtp(a.challenge!.code);
      await a.completeProfile(ownerName: 'M', storeName: 'S');
      await a.deleteAccount();
      expect(a.accountExists('+639171234567'), false);
      await a.requestOtp('09171234567');
      await a.verifyOtp(a.challenge!.code);
      expect(a.needsProfile, true); // treated as new seller again
    });
  });
}
