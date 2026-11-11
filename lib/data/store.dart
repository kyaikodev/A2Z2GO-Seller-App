import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import 'models.dart';
import 'sample_data.dart';

/// Result of an action that can fail with a message for the seller.
class Result {
  final String? error;
  const Result.ok() : error = null;
  const Result.fail(this.error);
  bool get ok => error == null;
}

/// All of one seller's business data. Starts EMPTY for a new seller, is saved
/// on the phone after every change, and is namespaced per account so two
/// sellers on one phone never see each other's data.
///
/// Later, swap the `_load` / `_save` pair for API calls and nothing else in the
/// app has to change.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.account);

  final SharedPreferences _prefs;
  final SellerAccount account;

  final List<Product> products = [];
  final List<StockMove> moves = [];
  final List<Order> orders = [];
  final List<ReturnRequest> returns = [];
  final List<Expense> expenses = [];
  final List<LoyaltyTxn> loyaltyTxns = [];
  LoyaltyConfig loyalty = LoyaltyConfig();
  int _orderCounter = 1000;

  String get _key => 'data_${account.phone}';

  static Future<AppStore> open(
    SharedPreferences prefs,
    SellerAccount account,
  ) async {
    final s = AppStore._(prefs, account);
    s._load();
    return s;
  }

  // ------------------------------------------------------------ persistence

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
          ((j[k] as List?) ?? [])
              .map((e) => f(Map<String, dynamic>.from(e as Map)))
              .toList();
      products.addAll(list('products', Product.fromJson));
      moves.addAll(list('moves', StockMove.fromJson));
      orders.addAll(list('orders', Order.fromJson));
      returns.addAll(list('returns', ReturnRequest.fromJson));
      expenses.addAll(list('expenses', Expense.fromJson));
      loyaltyTxns.addAll(list('loyaltyTxns', LoyaltyTxn.fromJson));
      if (j['loyalty'] != null) {
        loyalty = LoyaltyConfig.fromJson(
          Map<String, dynamic>.from(j['loyalty'] as Map),
        );
      }
      _orderCounter = (j['orderCounter'] as num?)?.toInt() ?? 1000;
    } catch (_) {
      // Corrupt data: keep a backup copy instead of silently wiping it.
      _prefs.setString('${_key}_backup', raw);
    }
  }

  Future<void> _chain = Future.value();

  void _commit() {
    notifyListeners();
    final payload = jsonEncode({
      'products': products.map((e) => e.toJson()).toList(),
      'moves': moves.map((e) => e.toJson()).toList(),
      'orders': orders.map((e) => e.toJson()).toList(),
      'returns': returns.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'loyaltyTxns': loyaltyTxns.map((e) => e.toJson()).toList(),
      'loyalty': loyalty.toJson(),
      'orderCounter': _orderCounter,
    });
    _chain = _chain.then((_) => _prefs.setString(_key, payload));
  }

  /// Completes when everything queued so far has been written.
  Future<void> flush() => _chain;

  // --------------------------------------------------------------- products

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<String> get categories {
    final set = <String>{...products.map((p) => p.category)};
    return set.toList()..sort();
  }

  String nextSku() {
    var n = products.length + 1;
    String sku() => 'SKU-${n.toString().padLeft(4, '0')}';
    while (products.any((p) => p.sku == sku())) {
      n++;
    }
    return sku();
  }

  Result addProduct(Product p) {
    if (products.any((e) => e.sku.toLowerCase() == p.sku.toLowerCase())) {
      return const Result.fail('That SKU is already used by another product.');
    }
    final opening = p.stock;
    p.stock = 0;
    products.add(p);
    if (opening > 0) {
      _move(p, MoveType.stockIn, opening, note: 'Opening stock');
    }
    _commit();
    return const Result.ok();
  }

  Result updateProduct(Product p) {
    if (products.any(
      (e) => e.id != p.id && e.sku.toLowerCase() == p.sku.toLowerCase(),
    )) {
      return const Result.fail('That SKU is already used by another product.');
    }
    _commit();
    return const Result.ok();
  }

  /// Removes the product (past orders keep their own copy of name and prices).
  void deleteProduct(Product p) {
    products.removeWhere((e) => e.id == p.id);
    moves.removeWhere((m) => m.productId == p.id);
    _deleteLocalImages(p);
    _commit();
  }

  /// Photos that live on this phone are deleted with the product; web
  /// addresses are only references.
  void _deleteLocalImages(Product p) {
    for (final path in p.images) {
      if (path.startsWith('http') || path.startsWith('blob:')) continue;
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  StockMove _move(
    Product p,
    MoveType type,
    int delta, {
    String note = '',
    String? orderId,
  }) {
    p.stock += delta;
    final m = StockMove(
      id: newId('m'),
      productId: p.id,
      productName: p.name,
      type: type,
      delta: delta,
      unitCost: p.cost,
      note: note,
      orderId: orderId,
    );
    moves.add(m);
    return m;
  }

  List<StockMove> movesFor(String productId) =>
      moves.where((m) => m.productId == productId).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  /// [qty] is always positive except for [MoveType.adjust], where it is the
  /// counted quantity the stock should now be.
  Result adjustStock(Product p, MoveType type, int qty, {String note = ''}) {
    if (qty < 0 || (qty == 0 && type != MoveType.adjust)) {
      return const Result.fail('Enter a quantity greater than zero.');
    }
    switch (type) {
      case MoveType.stockIn:
        _move(p, type, qty, note: note);
      case MoveType.stockOut:
      case MoveType.damaged:
        if (qty > p.stock) {
          return Result.fail('Only ${p.stock} in stock.');
        }
        _move(p, type, -qty, note: note);
      case MoveType.adjust:
        final delta = qty - p.stock;
        if (delta == 0) return Result.fail('Stock is already $qty.');
        _move(p, type, delta, note: note.isEmpty ? 'Counted $qty' : note);
      default:
        return const Result.fail('Unsupported stock action.');
    }
    _commit();
    return const Result.ok();
  }

  // ----------------------------------------------------------------- orders

  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Result createOrder({
    required String customerName,
    required String customerPhone,
    required Map<Product, int> lines,
    required double discount,
    required String payment,
    required String note,
  }) {
    if (lines.isEmpty) return const Result.fail('Add at least one product.');
    for (final e in lines.entries) {
      if (e.value <= 0) {
        return const Result.fail('Quantities must be above zero.');
      }
      if (e.value > e.key.stock) {
        return Result.fail(
          'Not enough stock for ${e.key.name} (only ${e.key.stock} left).',
        );
      }
    }
    final items = lines.entries
        .map(
          (e) => OrderItem(
            productId: e.key.id,
            name: e.key.name,
            qty: e.value,
            unitPrice: e.key.price,
            unitCost: e.key.cost,
          ),
        )
        .toList();
    final subtotal = r2(items.fold(0.0, (s, i) => s + i.lineTotal));
    if (discount < 0 || discount > subtotal) {
      return const Result.fail('Discount cannot be more than the order total.');
    }
    _orderCounter++;
    final order = Order(
      id: newId('o'),
      number: _orderCounter,
      customerName: customerName.trim(),
      customerPhone: customerPhone,
      items: items,
      discount: discount,
      payment: payment,
      note: note.trim(),
    );
    orders.add(order);
    for (final e in lines.entries) {
      _move(
        e.key,
        MoveType.sale,
        -e.value,
        note: 'Order #${order.number}',
        orderId: order.id,
      );
    }
    _commit();
    return const Result.ok();
  }

  /// Pending → Packed → Shipped → Completed.
  void advanceOrder(Order o) {
    final next = o.status.next;
    if (next == null) return;
    o.status = next;
    if (next == OrderStatus.completed) {
      o.completedAt = DateTime.now();
      _awardPoints(o);
    }
    _commit();
  }

  void cancelOrder(Order o) {
    if (!o.status.isOpen) return;
    o.status = OrderStatus.cancelled;
    _restoreStock(o, MoveType.restore, 'Order #${o.number} cancelled');
    _commit();
  }

  void _restoreStock(Order o, MoveType type, String note) {
    for (final i in o.items) {
      final p = productById(i.productId);
      if (p != null) _move(p, type, i.qty, note: note, orderId: o.id);
    }
  }

  /// Deleting an open order puts its stock back. A completed order was already
  /// delivered, so its stock is not restored (record a return for that).
  void deleteOrder(Order o) {
    if (o.status.isOpen) {
      _restoreStock(o, MoveType.restore, 'Order #${o.number} deleted');
    }
    orders.removeWhere((e) => e.id == o.id);
    returns.removeWhere((r) => r.orderId == o.id);
    loyaltyTxns.removeWhere((t) => t.orderId == o.id);
    // Stock history is kept on purpose so it always adds up to the stock count.
    _commit();
  }

  // ---------------------------------------------------------------- returns

  /// How many of this order's item can still be returned.
  int returnableQty(Order o, String productId) {
    final sold = o.items
        .where((i) => i.productId == productId)
        .fold(0, (s, i) => s + i.qty);
    final already = returns
        .where((r) => r.orderId == o.id && r.status != ReturnStatus.rejected)
        .expand((r) => r.items)
        .where((i) => i.productId == productId)
        .fold(0, (s, i) => s + i.qty);
    return sold - already;
  }

  /// Refund the customer would get for these items (discount shared fairly).
  double suggestedRefund(Order o, Map<OrderItem, int> qtys) {
    final gross = qtys.entries.fold(
      0.0,
      (s, e) => s + e.key.unitPrice * e.value,
    );
    final ratio = o.subtotal <= 0 ? 1.0 : o.total / o.subtotal;
    return r2(gross * ratio);
  }

  Result createReturn({
    required Order order,
    required Map<OrderItem, int> qtys,
    required String reason,
    required String note,
    required double refund,
    required bool restock,
  }) {
    if (order.status != OrderStatus.completed) {
      return const Result.fail('Only completed orders can be returned.');
    }
    final chosen = qtys.entries.where((e) => e.value > 0).toList();
    if (chosen.isEmpty) return const Result.fail('Pick at least one item.');
    for (final e in chosen) {
      if (e.value > returnableQty(order, e.key.productId)) {
        return Result.fail('Too many of ${e.key.name} selected.');
      }
    }
    if (refund < 0) return const Result.fail('Refund cannot be negative.');
    returns.add(
      ReturnRequest(
        id: newId('r'),
        orderId: order.id,
        orderNumber: order.number,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: chosen
            .map(
              (e) => ReturnItem(
                productId: e.key.productId,
                name: e.key.name,
                qty: e.value,
                unitPrice: e.key.unitPrice,
                unitCost: e.key.unitCost,
              ),
            )
            .toList(),
        reason: reason,
        note: note.trim(),
        refund: refund,
        restock: restock,
      ),
    );
    _commit();
    return const Result.ok();
  }

  void approveReturn(ReturnRequest r) {
    if (r.status != ReturnStatus.requested) return;
    r.status = ReturnStatus.approved;
    r.resolvedAt = DateTime.now();
    if (r.restock) {
      for (final i in r.items) {
        final p = productById(i.productId);
        if (p != null) {
          _move(
            p,
            MoveType.returned,
            i.qty,
            note: 'Return from order #${r.orderNumber}',
            orderId: r.orderId,
          );
        }
      }
    }
    if (loyalty.enabled &&
        r.customerPhone.isNotEmpty &&
        loyalty.pesoPerPoint > 0) {
      final pts = (r.refund / loyalty.pesoPerPoint).floor();
      if (pts > 0) {
        loyaltyTxns.add(
          LoyaltyTxn(
            id: newId('l'),
            phone: r.customerPhone,
            name: r.customerName,
            points: -pts,
            type: LoyaltyType.reversal,
            orderId: r.orderId,
            note: 'Refund on order #${r.orderNumber}',
          ),
        );
      }
    }
    _commit();
  }

  void rejectReturn(ReturnRequest r) {
    if (r.status != ReturnStatus.requested) return;
    r.status = ReturnStatus.rejected;
    r.resolvedAt = DateTime.now();
    _commit();
  }

  /// Deleting an approved return also undoes its stock and points effects.
  void deleteReturn(ReturnRequest r) {
    if (r.status == ReturnStatus.approved) {
      if (r.restock) {
        for (final i in r.items) {
          final p = productById(i.productId);
          if (p != null) {
            final back = i.qty > p.stock ? p.stock : i.qty;
            if (back > 0) {
              _move(
                p,
                MoveType.adjust,
                -back,
                note: 'Return on order #${r.orderNumber} deleted',
                orderId: r.orderId,
              );
            }
          }
        }
      }
      loyaltyTxns.removeWhere(
        (t) =>
            t.type == LoyaltyType.reversal &&
            t.orderId == r.orderId &&
            t.note == 'Refund on order #${r.orderNumber}',
      );
    }
    returns.removeWhere((e) => e.id == r.id);
    _commit();
  }

  // --------------------------------------------------------------- expenses

  void addExpense(Expense e) {
    expenses.add(e);
    _commit();
  }

  void updateExpense(Expense e) => _commit();

  void deleteExpense(Expense e) {
    expenses.removeWhere((x) => x.id == e.id);
    _commit();
  }

  // ---------------------------------------------------------------- loyalty

  void saveLoyaltyConfig() => _commit();

  void _awardPoints(Order o) {
    if (!loyalty.enabled ||
        o.customerPhone.isEmpty ||
        loyalty.pesoPerPoint <= 0) {
      return;
    }
    final pts = (o.total / loyalty.pesoPerPoint).floor();
    if (pts <= 0) return;
    loyaltyTxns.add(
      LoyaltyTxn(
        id: newId('l'),
        phone: o.customerPhone,
        name: o.customerName,
        points: pts,
        type: LoyaltyType.earn,
        orderId: o.id,
        note: 'Order #${o.number}',
      ),
    );
  }

  /// Everyone who has earned points, with live balances.
  List<LoyaltyCustomer> get loyaltyCustomers {
    final map = <String, LoyaltyCustomer>{};
    final sorted = [...loyaltyTxns]..sort((a, b) => a.at.compareTo(b.at));
    for (final t in sorted) {
      final c = map.putIfAbsent(
        t.phone,
        () => LoyaltyCustomer(phone: t.phone, name: t.name),
      );
      if (t.name.trim().isNotEmpty) c.name = t.name;
      c.balance += t.points;
      if (t.points > 0 && t.type == LoyaltyType.earn) c.earned += t.points;
      if (t.type == LoyaltyType.redeem) c.redeemed += -t.points;
      c.lastActivity = t.at;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  List<LoyaltyTxn> txnsFor(String phone) =>
      loyaltyTxns.where((t) => t.phone == phone).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  int balanceOf(String phone) => loyaltyTxns
      .where((t) => t.phone == phone)
      .fold(0, (s, t) => s + t.points);

  Result redeemPoints(LoyaltyCustomer c, int points, String note) {
    if (points <= 0) return const Result.fail('Enter points above zero.');
    if (points > c.balance) {
      return Result.fail(
        '${c.name.isEmpty ? 'Customer' : c.name} only has ${c.balance} points.',
      );
    }
    loyaltyTxns.add(
      LoyaltyTxn(
        id: newId('l'),
        phone: c.phone,
        name: c.name,
        points: -points,
        type: LoyaltyType.redeem,
        note: note,
      ),
    );
    _commit();
    return const Result.ok();
  }

  Result adjustPoints(LoyaltyCustomer c, int delta, String note) {
    if (delta == 0) return const Result.fail('Enter a number other than zero.');
    if (c.balance + delta < 0) {
      return const Result.fail('That would make the balance negative.');
    }
    loyaltyTxns.add(
      LoyaltyTxn(
        id: newId('l'),
        phone: c.phone,
        name: c.name,
        points: delta,
        type: LoyaltyType.adjust,
        note: note,
      ),
    );
    _commit();
    return const Result.ok();
  }

  /// Gives points to a customer by phone (creating them if new).
  Result addCustomerPoints(String phone, String name, int points, String note) {
    if (points <= 0) return const Result.fail('Enter points above zero.');
    loyaltyTxns.add(
      LoyaltyTxn(
        id: newId('l'),
        phone: phone,
        name: name.trim(),
        points: points,
        type: LoyaltyType.adjust,
        note: note.isEmpty ? 'Manual points' : note,
      ),
    );
    _commit();
    return const Result.ok();
  }

  // ---------------------------------------------------------------- account

  void updateAccount({String? ownerName, String? storeName, String? address}) {
    if (ownerName != null) account.ownerName = ownerName;
    if (storeName != null) account.storeName = storeName;
    if (address != null) account.address = address;
    _commit();
  }

  /// Wipes every record for this seller (account stays).
  void eraseAllData() {
    products.forEach(_deleteLocalImages);
    products.clear();
    moves.clear();
    orders.clear();
    returns.clear();
    expenses.clear();
    loyaltyTxns.clear();
    loyalty = LoyaltyConfig();
    _orderCounter = 1000;
    _commit();
  }

  // ------------------------------------------------------------ sample data

  /// Adds a demo shop (products, orders over the last 10 days, a pending
  /// return, expenses). It goes through the normal store functions, so stock,
  /// history, profit and loyalty points all stay consistent, and the seller
  /// can then edit or delete any of it. Never runs on its own.
  Result loadSampleData() {
    if (products.any((p) => p.sku == sampleFirstSku)) {
      return const Result.fail('Sample data is already in your shop.');
    }
    final now = DateTime.now();
    DateTime at(int daysAgo, int hour) {
      final d = DateTime(now.year, now.month, now.day - daysAgo, hour);
      return d.isAfter(now) ? now : d;
    }

    for (final s in sampleProducts) {
      addProduct(
        Product(
          id: newId('p'),
          sku: s.sku,
          name: s.name,
          category: s.category,
          description: s.description,
          price: s.price,
          cost: s.cost,
          stock: s.stock,
          lowStockAt: s.lowStockAt,
          active: s.active,
          brand: s.brand,
          sourceUrl: s.sourceUrl,
          images: [...s.images],
          posts: s.postUrl.isEmpty
              ? null
              : [
                  SocialPost(
                    id: newId('s'),
                    platform: SocialPlatformX.fromUrl(s.postUrl),
                    url: s.postUrl,
                    title: s.postCaption,
                    comments: [
                      for (final c in s.comments)
                        SharedComment(
                          id: newId('c'),
                          author: c[0],
                          text: c[1],
                          demo: true,
                        ),
                    ],
                  ),
                ],
          createdAt: at(10, 9),
        ),
      );
    }

    Order? returnable;
    for (final s in sampleOrders) {
      final lines = <Product, int>{};
      for (final e in s.lines.entries) {
        final p = products.where((p) => p.sku == e.key).firstOrNull;
        if (p != null) lines[p] = e.value;
      }
      final res = createOrder(
        customerName: s.customer,
        customerPhone: normalizePhone(s.phone) ?? '',
        lines: lines,
        discount: s.discount,
        payment: s.payment,
        note: s.note,
      );
      if (!res.ok) continue;
      final o = orders.last;
      o.createdAt = at(s.daysAgo, s.hour);
      switch (s.status) {
        case 'cancelled':
          cancelOrder(o);
        case 'completed':
          while (o.status != OrderStatus.completed) {
            advanceOrder(o);
          }
          final done = o.createdAt.add(const Duration(hours: 3));
          o.completedAt = done.isAfter(now) ? now : done;
          if (s.daysAgo == 8) returnable = o;
        case 'shipped':
          advanceOrder(o);
          advanceOrder(o);
        case 'packed':
          advanceOrder(o);
      }
    }

    // One customer return waiting for the seller's decision.
    final ro = returnable;
    if (ro != null) {
      final item = ro.items.where((i) => i.name == 'Wireless Earbuds').first;
      createReturn(
        order: ro,
        qtys: {item: 1},
        reason: 'Defective item',
        note: 'No sound on the left earbud',
        refund: item.unitPrice,
        restock: false,
      );
    }

    for (final e in sampleExpenses) {
      addExpense(
        Expense(
          id: newId('e'),
          title: e.title,
          category: e.category,
          amount: e.amount,
          date: at(e.daysAgo, 12),
        ),
      );
    }
    _commit();
    return const Result.ok();
  }

  // -------------------------------------------------------------- shortcuts

  List<Product> get lowStock =>
      products.where((p) => p.active && (p.isLow || p.isOut)).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
}
