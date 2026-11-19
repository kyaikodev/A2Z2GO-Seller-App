import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/format.dart';
import 'package:a2z2go_seller/data/auth.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/reports.dart';
import 'package:a2z2go_seller/data/storage.dart';
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

    test('deleting one of two returns on an order keeps the other\'s points '
        'reversal', () async {
      final (s, _, o) = await completed();
      for (var i = 0; i < 2; i++) {
        s.createReturn(
          order: o,
          qtys: {o.items[0]: 2},
          reason: 'x',
          note: '',
          refund: 180,
          restock: false,
        );
      }
      for (final r in [...s.returns]) {
        s.approveReturn(r);
      }
      // 3 earned; the first refund takes back 1, the second the other 2
      expect(s.balanceOf('+639170000001'), 0);
      s.deleteReturn(s.returns.first);
      expect(s.balanceOf('+639170000001'), 1); // only that return is undone
    });

    test('a refund cannot be more than what is left on the order', () async {
      final (s, _, o) = await completed(); // order total is 360
      Result ask(double refund, int qty) => s.createReturn(
        order: o,
        qtys: {o.items[0]: qty},
        reason: 'x',
        note: '',
        refund: refund,
        restock: true,
      );
      expect(ask(100000, 1).ok, false);
      expect(s.returns, isEmpty);
      expect(ask(200, 1).ok, true);
      expect(s.refundableLeft(o), 160);
      expect(ask(200, 1).ok, false); // 200 is more than the 160 left
      expect(ask(160, 1).ok, true);
      expect(s.refundableLeft(o), 0);
      // a rejected return gives its amount back
      s.rejectReturn(s.returns.first);
      expect(s.refundableLeft(o), 200);
    });

    test(
      'points reversal follows the points earned, not the current rate',
      () async {
        final (s, _, o) = await completed(); // earned 3 points on 360
        s.loyalty.pesoPerPoint = 10; // the seller changes the rule later
        s.createReturn(
          order: o,
          qtys: {o.items[0]: 2},
          reason: 'x',
          note: '',
          refund: 180, // half of the order
          restock: true,
        );
        s.approveReturn(s.returns.single);
        expect(s.balanceOf('+639170000001'), 2); // 1 of 3 points taken back
      },
    );

    test('a full refund takes back all earned points, even with loyalty off, '
        'and never more', () async {
      final (s, _, o) = await completed();
      s.loyalty.enabled = false;
      s.createReturn(
        order: o,
        qtys: {o.items[0]: 4},
        reason: 'x',
        note: '',
        refund: 360,
        restock: true,
      );
      s.approveReturn(s.returns.single);
      expect(s.balanceOf('+639170000001'), 0);
    });
  });

  group('sku and corrupt data', () {
    test('skuTaken ignores the product itself and letter case', () async {
      final s = await freshStore();
      final a = mk(s);
      final b = mk(s);
      expect(s.skuTaken(a.sku.toLowerCase(), exceptId: b.id), true);
      expect(s.skuTaken(a.sku, exceptId: a.id), false);
      b.sku = a.sku;
      expect(s.updateProduct(b).ok, false);
    });

    test('one unreadable part loads nothing and keeps a backup', () async {
      final s1 = await freshStore();
      mk(s1);
      await s1.flush();
      const key = 'data_+639171234567';
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      j['orders'] = [5]; // not a valid order
      final bad = jsonEncode(j);
      SharedPreferences.setMockInitialValues({key: bad});
      final s2 = await AppStore.open(
        await SharedPreferences.getInstance(),
        SellerAccount(
          phone: '+639171234567',
          ownerName: 'Mayari',
          storeName: 'Sari-Sari',
        ),
      );
      expect(s2.products, isEmpty); // not half-loaded
      final p2 = await SharedPreferences.getInstance();
      expect(p2.getString('${key}_backup'), bad);
    });
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
        await s.flush();
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
  group('review fixes', () {
    Future<(AppStore, Product, Order)> done({int qty = 4}) async {
      final s = await freshStore();
      final p = mk(s, price: 100, cost: 60, stock: 10);
      s.createOrder(
        customerName: 'Ana',
        customerPhone: '+639170000001',
        lines: {p: qty},
        discount: 0,
        payment: 'Cash',
        note: '',
      );
      final o = s.orders.single;
      while (o.status.next != null) {
        s.advanceOrder(o);
      }
      return (s, p, o);
    }

    test('undoing a completion removes the sale and its points', () async {
      final (s, _, o) = await done();
      expect(Report.build(s, Period.days(7)).netSales, 400);
      expect(s.balanceOf('+639170000001'), 4);
      expect(s.undoCompletion(o).ok, true);
      expect(o.status, OrderStatus.shipped);
      expect(o.completedAt, isNull);
      expect(Report.build(s, Period.days(7)).netSales, 0);
      expect(s.balanceOf('+639170000001'), 0);
    });

    test('a completion with a return cannot be undone', () async {
      final (s, _, o) = await done();
      s.createReturn(
        order: o,
        qtys: {o.items[0]: 1},
        reason: 'x',
        note: '',
        refund: 100,
        restock: true,
      );
      expect(s.undoCompletion(o).ok, false);
      expect(o.status, OrderStatus.completed);
    });

    test('deleting a completed order can put the stock back', () async {
      final (s, p, o) = await done();
      expect(p.stock, 6);
      s.deleteOrder(o, restoreStock: true);
      expect(p.stock, 10);
      final (s2, p2, o2) = await done();
      s2.deleteOrder(o2); // default: stock stays gone (it was delivered)
      expect(p2.stock, 6);
    });

    test('a product used by an open order cannot be deleted blindly', () async {
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
      expect(s.productInUse(p), true);
      s.cancelOrder(s.orders.single);
      expect(s.productInUse(p), false);
    });

    test('best-seller revenue drops by the refund', () async {
      final (s, _, o) = await done();
      s.createReturn(
        order: o,
        qtys: {o.items[0]: 2},
        reason: 'x',
        note: '',
        refund: 200,
        restock: true,
      );
      s.approveReturn(s.returns.single);
      final r = Report.build(s, Period.days(7));
      expect(r.netSales, 200);
      expect(r.bestSellers.single.qty, 2);
      expect(r.bestSellers.single.revenue, 200);
    });

    test(
      'saved data carries a version and UTC times, and reloads the same',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final acct = SellerAccount(
          phone: '+639171234567',
          ownerName: 'A',
          storeName: 'S',
        );
        final s1 = await AppStore.open(prefs, acct);
        final p = mk(s1);
        s1.createOrder(
          customerName: 'B',
          customerPhone: '',
          lines: {p: 1},
          discount: 0,
          payment: 'Cash',
          note: '',
        );
        await s1.flush();
        final raw = prefs.getString('data_+639171234567')!;
        expect(raw.contains('"version":1'), true);
        expect(RegExp(r'"createdAt":"[^"]+Z"').hasMatch(raw), true);
        final s2 = await AppStore.open(prefs, acct);
        expect(
          s2.orders.single.createdAt.millisecondsSinceEpoch,
          s1.orders.single.createdAt.millisecondsSinceEpoch,
        );
      },
    );

    test('a refused product edit changes nothing', () async {
      final s = await freshStore();
      final a = mk(s);
      final b = mk(s);
      final res = s.applyProductEdit(
        b,
        sku: a.sku,
        name: 'Renamed',
        category: 'X',
        brand: '',
        sourceUrl: '',
        description: '',
        price: 5,
        cost: 1,
        lowStockAt: 1,
        images: [],
        posts: [],
        active: true,
      );
      expect(res.ok, false);
      expect(b.name, 'Soap');
      expect(b.price, 100);
    });

    test('reports are reused until something changes', () async {
      final (s, _, _) = await done();
      final p = Period.days(7);
      final first = s.report(p);
      expect(identical(first, s.report(p)), true);
      s.addExpense(Expense(id: 'e', title: 't', category: 'Other', amount: 5));
      expect(identical(first, s.report(p)), false);
    });

    test('money and phone helpers', () {
      expect(pesoShort(999999), '₱1.0M');
      expect(pesoShort(1250), '₱1.3K');
      expect(plainAmount(1250), '1250');
      expect(plainAmount(12.5), '12.50');
      expect(phoneMatches('+639171234567', '0917 123'), true);
      expect(phoneMatches('+639171234567', '+63 917'), true);
      expect(phoneMatches('+639171234567', '0918'), false);
      expect(phoneMatches('+639171234567', '09'), false); // too short
    });
  });
  group('file storage', () {
    final acct = SellerAccount(
      phone: '+639171234567',
      ownerName: 'A',
      storeName: 'S',
    );

    test('data saved in preferences moves to files on first open', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final old = await AppStore.open(prefs, acct); // old way: preferences
      mk(old);
      await old.flush();
      expect(prefs.getString('data_+639171234567'), isNotNull);

      final dir = Directory.systemTemp.createTempSync('shop_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final files = FileStorage(dir);

      final moved = await AppStore.open(prefs, acct, storage: files);
      expect(moved.products.length, 1); // nothing lost in the move
      expect(prefs.getString('data_+639171234567'), isNull); // old copy dropped
      expect(File('${dir.path}/data_+639171234567.json').existsSync(), true);

      mk(moved); // later changes go to the file
      await moved.flush();
      final again = await AppStore.open(prefs, acct, storage: files);
      expect(again.products.length, 2);
      expect(
        dir.listSync().any((f) => f.path.endsWith('.tmp')),
        false,
      ); // no half-written leftovers
    });

    test(
      'a burst of changes is written once, and flush writes at once',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final counting = _CountingStorage(PrefsStorage(prefs));
        final s = await AppStore.open(prefs, acct, storage: counting);
        for (var i = 0; i < 5; i++) {
          s.addExpense(
            Expense(id: 'e$i', title: 't', category: 'Other', amount: 1),
          );
        }
        expect(counting.writes, 0); // grouped, not yet written
        await s.flush();
        expect(counting.writes, 1);
        await s.flush(); // nothing new: nothing written
        expect(counting.writes, 1);
        final s2 = await AppStore.open(prefs, acct);
        expect(s2.expenses.length, 5);
      },
    );

    test('delete-account style cleanup removes the file', () async {
      final dir = Directory.systemTemp.createTempSync('shop_test2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final files = FileStorage(dir);
      await files.write('data_x', '{}');
      expect(await files.read('data_x'), '{}');
      await files.remove('data_x');
      expect(await files.read('data_x'), isNull);
    });
  });
  group('points on orders and order edits', () {
    const phone = '+639170000001';

    /// A customer who already holds 3 points, and a product to sell.
    Future<(AppStore, Product)> customerWithPoints() async {
      final s = await freshStore();
      final p = mk(s, price: 100, cost: 60, stock: 20);
      s.createOrder(
        customerName: 'Ana',
        customerPhone: phone,
        lines: {p: 4},
        discount: 40,
        payment: 'Cash',
        note: '',
      );
      final first = s.orders.single;
      while (first.status.next != null) {
        s.advanceOrder(first);
      }
      expect(s.balanceOf(phone), 3);
      return (s, p);
    }

    Result order(AppStore s, Product p, {int points = 0, String ph = phone}) =>
        s.createOrder(
          customerName: 'Ana',
          customerPhone: ph,
          lines: {p: 2},
          discount: 0,
          payment: 'Cash',
          note: '',
          redeemPoints: points,
        );

    test(
      'points paid on an order become a discount and leave the balance',
      () async {
        final (s, p) = await customerWithPoints();
        expect(order(s, p, points: 2).ok, true);
        final o = s.orders.last;
        expect(o.pointsUsed, 2);
        expect(o.discount, 2); // 1 point is worth 1 peso by default
        expect(o.total, 198);
        expect(s.balanceOf(phone), 1);
      },
    );

    test(
      'points cannot be spent without a number or beyond the balance',
      () async {
        final (s, p) = await customerWithPoints();
        expect(order(s, p, points: 99).ok, false);
        expect(order(s, p, points: 1, ph: '').ok, false);
        expect(s.orders.length, 1); // neither created an order
        expect(s.balanceOf(phone), 3);
      },
    );

    test('cancelling or deleting the order gives the points back', () async {
      final (s, p) = await customerWithPoints();
      order(s, p, points: 2);
      s.cancelOrder(s.orders.last);
      expect(s.balanceOf(phone), 3);
      order(s, p, points: 2);
      expect(s.balanceOf(phone), 1);
      s.deleteOrder(s.orders.last);
      expect(s.balanceOf(phone), 3);
    });

    test(
      'order details can be fixed, but not the number once completed',
      () async {
        final (s, p) = await customerWithPoints();
        final done = s.orders.first; // completed
        expect(
          s
              .updateOrderDetails(
                done,
                name: 'Anna',
                phone: '+639179999999',
                note: 'x',
              )
              .ok,
          false,
        );
        expect(done.customerPhone, phone);
        expect(
          s
              .updateOrderDetails(
                done,
                name: 'Anna',
                phone: phone,
                note: 'gift',
              )
              .ok,
          true,
        );
        expect(done.customerName, 'Anna');
        expect(done.note, 'gift');

        order(s, p); // open order: the number may change
        final open = s.orders.last;
        expect(
          s
              .updateOrderDetails(
                open,
                name: 'B',
                phone: '+639178888888',
                note: '',
              )
              .ok,
          true,
        );
        expect(open.customerPhone, '+639178888888');
      },
    );
  });
  group('backup and restore', () {
    test('a backup restores every record into another shop', () async {
      final a = await freshStore();
      final p = mk(a, price: 100, cost: 60, stock: 10);
      a.createOrder(
        customerName: 'Ana',
        customerPhone: '+639170000001',
        lines: {p: 4},
        discount: 40,
        payment: 'Cash',
        note: 'gift',
      );
      final o = a.orders.single;
      while (o.status.next != null) {
        a.advanceOrder(o);
      }
      a.addExpense(
        Expense(id: 'e1', title: 'Ads', category: 'Other', amount: 99),
      );
      final text = a.exportJson();

      final b = await freshStore();
      mk(b); // something that the restore must replace
      expect(b.restoreFromJson(text).ok, true);
      expect(b.products.single.name, 'Soap');
      expect(b.products.single.stock, 6);
      expect(b.orders.single.note, 'gift');
      expect(b.orders.single.total, 360);
      expect(b.expenses.single.amount, 99);
      expect(b.balanceOf('+639170000001'), 3);
      expect(b.moves.length, a.moves.length);
    });

    test('a file that is not a backup changes nothing', () async {
      final s = await freshStore();
      mk(s);
      expect(s.restoreFromJson('not json at all').ok, false);
      expect(s.restoreFromJson('{"products": []}').ok, false); // no marker
      expect(
        s.restoreFromJson('{"app":"a2z2go_seller_backup","orders":[5]}').ok,
        false, // marker, but a record that cannot be read
      );
      expect(s.products.length, 1); // still the original data
    });
  });
}

/// Counts how many times the store actually writes.
class _CountingStorage implements StoreStorage {
  _CountingStorage(this.inner);
  final StoreStorage inner;
  int writes = 0;

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) {
    writes++;
    return inner.write(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);
}
