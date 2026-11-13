import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import 'models.dart';
import 'reports.dart';
import 'sample_data.dart';
import 'storage.dart';

/// Result of an action that can fail with a message for the seller.
class Result {
  final String? error;
  const Result.ok() : error = null;
  const Result.fail(this.error);
  bool get ok => error == null;
}

/// Everything read from saved data, held aside until all of it has read well.
class _Data {
  _Data({
    required this.products,
    required this.moves,
    required this.orders,
    required this.returns,
    required this.expenses,
    required this.loyaltyTxns,
    required this.loyalty,
    required this.orderCounter,
  });
  final List<Product> products;
  final List<StockMove> moves;
  final List<Order> orders;
  final List<ReturnRequest> returns;
  final List<Expense> expenses;
  final List<LoyaltyTxn> loyaltyTxns;
  final LoyaltyConfig? loyalty;
  final int orderCounter;
}

/// All of one seller's business data. Starts EMPTY for a new seller, is saved
/// on the phone after every change, and is namespaced per account so two
/// sellers on one phone never see each other's data.
///
/// Later, swap the `_load` / `_save` pair for API calls and nothing else in the
/// app has to change.
class AppStore extends ChangeNotifier {
  AppStore._(this._storage, this.account);

  final StoreStorage _storage;
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

  /// Opens a seller's data. [storage] is where it lives (files in the app,
  /// preferences by default). Data saved by older versions in [prefs] is moved
  /// into [storage] the first time.
  static Future<AppStore> open(
    SharedPreferences prefs,
    SellerAccount account, {
    StoreStorage? storage,
  }) async {
    final store = storage ?? PrefsStorage(prefs);
    final s = AppStore._(store, account);
    var raw = await store.read(s._key);
    if (raw == null && store is! PrefsStorage) {
      // First run after the move from preferences to files: copy the data over,
      // and only drop the old copy once the new one reads back identical.
      final old = prefs.getString(s._key);
      if (old != null) {
        await store.write(s._key, old);
        if (await store.read(s._key) == old) await prefs.remove(s._key);
        raw = old;
      }
    }
    s._load(raw);
    return s;
  }

  // ------------------------------------------------------------ persistence

  void _load(String? raw) {
    if (raw == null) return;
    try {
      _apply(_parse(raw));
    } catch (_) {
      // Corrupt data: keep a backup copy instead of silently wiping it.
      _storage.write('${_key}_backup', raw);
    }
  }

  /// Reads saved data into lists WITHOUT touching the store, so a bad record
  /// never leaves a half-loaded store that the next save would write over the
  /// real data. Throws if anything is unreadable.
  _Data _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    return _Data(
      products: list('products', Product.fromJson),
      moves: list('moves', StockMove.fromJson),
      orders: list('orders', Order.fromJson),
      returns: list('returns', ReturnRequest.fromJson),
      expenses: list('expenses', Expense.fromJson),
      loyaltyTxns: list('loyaltyTxns', LoyaltyTxn.fromJson),
      loyalty: j['loyalty'] == null
          ? null
          : LoyaltyConfig.fromJson(
              Map<String, dynamic>.from(j['loyalty'] as Map),
            ),
      orderCounter: (j['orderCounter'] as num?)?.toInt() ?? 1000,
    );
  }

  /// Replaces everything in the store with [d].
  void _apply(_Data d) {
    products
      ..clear()
      ..addAll(d.products);
    moves
      ..clear()
      ..addAll(d.moves);
    orders
      ..clear()
      ..addAll(d.orders);
    returns
      ..clear()
      ..addAll(d.returns);
    expenses
      ..clear()
      ..addAll(d.expenses);
    loyaltyTxns
      ..clear()
      ..addAll(d.loyaltyTxns);
    loyalty = d.loyalty ?? LoyaltyConfig();
    _orderCounter = d.orderCounter;
  }

  Map<String, dynamic> _payloadMap() => {
    'version': 1, // bump when the saved shape changes, and migrate in _parse
    'products': products.map((e) => e.toJson()).toList(),
    'moves': moves.map((e) => e.toJson()).toList(),
    'orders': orders.map((e) => e.toJson()).toList(),
    'returns': returns.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'loyaltyTxns': loyaltyTxns.map((e) => e.toJson()).toList(),
    'loyalty': loyalty.toJson(),
    'orderCounter': _orderCounter,
  };

  static const _backupMarker = 'a2z2go_seller_backup';

  /// A copy of all records as text, for the seller to keep. Photos are files on
  /// the phone and are not part of it.
  String exportJson() => jsonEncode({
    'app': _backupMarker,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    ..._payloadMap(),
  });

  /// Replaces every record with a backup made by [exportJson]. Nothing changes
  /// if the text is not a readable backup.
  Result restoreFromJson(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['app'] != _backupMarker) {
        return const Result.fail('That file is not an A2Z2GO backup.');
      }
      _apply(_parse(text));
    } catch (_) {
      return const Result.fail('That backup could not be read.');
    }
    _commit();
    return const Result.ok();
  }

  Future<void> _chain = Future.value();

  // Reports are worked out once per change, not once per screen rebuild.
  int _version = 0;
  final _reportCache = <String, Report>{};
  Snapshot? _snapshot;

  Report report(Period p) => _reportCache.putIfAbsent(
    '$_version|${p.label}|${p.start.millisecondsSinceEpoch}',
    () => Report.build(this, p),
  );

  Snapshot get snapshot => _snapshot ??= Snapshot.of(this);

  // Saves are grouped: a burst of changes (loading sample data, a quick series
  // of taps) is written once, a moment later. [flush] writes right away; the
  // app calls it when it goes to the background.
  Timer? _saveTimer;
  bool _dirty = false;

  // shortcut: every save writes the whole store as one JSON file. Fine up to a
  // few thousand orders; past that, move to a database (see REVIEW.md F6).
  void _commit() {
    _version++;
    _reportCache.clear();
    _snapshot = null;
    notifyListeners();
    _dirty = true;
    _saveTimer ??= Timer(const Duration(milliseconds: 300), _save);
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    final payload = jsonEncode(_payloadMap());
    _chain = _chain.then((_) => _storage.write(_key, payload));
  }

  /// Writes any pending change now and completes when it is on disk.
  Future<void> flush() {
    _save();
    return _chain;
  }

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

  /// Categories to pick from: the ones already used first, then a starting
  /// list, so a new shop is not looking at an empty list.
  List<String> get categoryOptions {
    final used = categories;
    final lower = used.map((c) => c.toLowerCase()).toSet();
    return [
      ...used,
      for (final c in starterCategories)
        if (!lower.contains(c.toLowerCase())) c,
    ];
  }

  /// Brands already used on products.
  List<String> get brands {
    final set = <String>{
      for (final p in products)
        if (p.brand.trim().isNotEmpty) p.brand.trim(),
    };
    return set.toList()..sort();
  }

  /// Past customers from orders: name to mobile number (the latest given).
  Map<String, String> get customerPhones {
    final m = <String, String>{};
    for (final o in orders) {
      final n = o.customerName.trim();
      if (n.isEmpty) continue;
      if (o.customerPhone.isNotEmpty || !m.containsKey(n)) {
        m[n] = o.customerPhone;
      }
    }
    return m;
  }

  String nextSku() {
    var n = products.length + 1;
    String sku() => 'SKU-${n.toString().padLeft(4, '0')}';
    while (products.any((p) => p.sku == sku())) {
      n++;
    }
    return sku();
  }

  /// True when another product (not [exceptId]) already uses this SKU.
  bool skuTaken(String sku, {String? exceptId}) => products.any(
    (e) => e.id != exceptId && e.sku.toLowerCase() == sku.toLowerCase(),
  );

  Result addProduct(Product p) {
    if (skuTaken(p.sku)) {
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
    if (skuTaken(p.sku, exceptId: p.id)) {
      return const Result.fail('That SKU is already used by another product.');
    }
    _commit();
    return const Result.ok();
  }

  /// Changes a product's details after checking the new SKU, so a refused
  /// edit leaves the product exactly as it was.
  Result applyProductEdit(
    Product p, {
    required String sku,
    required String name,
    required String category,
    required String brand,
    required String sourceUrl,
    required String description,
    required double price,
    required double cost,
    required int lowStockAt,
    required List<String> images,
    required List<SocialPost> posts,
    required bool active,
  }) {
    if (skuTaken(sku, exceptId: p.id)) {
      return const Result.fail('That SKU is already used by another product.');
    }
    p
      ..sku = sku
      ..name = name
      ..category = category
      ..brand = brand
      ..sourceUrl = sourceUrl
      ..description = description
      ..price = price
      ..cost = cost
      ..lowStockAt = lowStockAt
      ..images = images
      ..posts = posts
      ..active = active;
    _commit();
    return const Result.ok();
  }

  /// True while an open order or a return waiting for a decision uses it.
  /// Deleting such a product would strand that order, so the screen offers to
  /// hide it instead.
  bool productInUse(Product p) =>
      orders.any(
        (o) => o.status.isOpen && o.items.any((i) => i.productId == p.id),
      ) ||
      returns.any(
        (r) =>
            r.status == ReturnStatus.requested &&
            r.items.any((i) => i.productId == p.id),
      );

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
      if (path.startsWith('http') ||
          path.startsWith('blob:') ||
          path.startsWith('asset:')) {
        continue;
      }
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
    int redeemPoints = 0,
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
    // Points the customer spends become part of the discount, and are taken off
    // their balance together with the order.
    var pointsValue = 0.0;
    if (redeemPoints != 0) {
      if (redeemPoints < 0 || !loyalty.enabled || customerPhone.isEmpty) {
        return const Result.fail(
          'Points can only be used with a mobile number.',
        );
      }
      if (redeemPoints > balanceOf(customerPhone)) {
        return const Result.fail(
          'The customer does not have that many points.',
        );
      }
      pointsValue = r2(redeemPoints * loyalty.pesoPerPointValue);
      if (r2(discount + pointsValue) > subtotal) {
        return const Result.fail('Those points are worth more than the order.');
      }
    }
    _orderCounter++;
    final order = Order(
      id: newId('o'),
      number: _orderCounter,
      customerName: customerName.trim(),
      customerPhone: customerPhone,
      items: items,
      discount: r2(discount + pointsValue),
      pointsUsed: redeemPoints,
      payment: payment,
      note: note.trim(),
    );
    orders.add(order);
    if (redeemPoints > 0) {
      loyaltyTxns.add(
        LoyaltyTxn(
          id: newId('l'),
          phone: customerPhone,
          name: customerName.trim(),
          points: -redeemPoints,
          type: LoyaltyType.redeem,
          orderId: order.id,
          note: 'Used on order #${order.number}',
        ),
      );
    }
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

  /// Fixes who the order is for and its note. The mobile number (where points
  /// go) cannot change once the order is completed or has used points.
  Result updateOrderDetails(
    Order o, {
    required String name,
    required String phone,
    required String note,
  }) {
    if (phone != o.customerPhone &&
        (o.status == OrderStatus.completed || o.pointsUsed > 0)) {
      return const Result.fail(
        'The mobile number cannot be changed after the order is completed or paid with points.',
      );
    }
    o
      ..customerName = name.trim()
      ..customerPhone = phone
      ..note = note.trim();
    _commit();
    return const Result.ok();
  }

  /// Takes an accidental "Completed" back to Shipped: the sale leaves the
  /// reports and the points it earned are removed. Not possible once a return
  /// has been recorded against it.
  Result undoCompletion(Order o) {
    if (o.status != OrderStatus.completed) {
      return const Result.fail('That order is not completed.');
    }
    if (returns.any((r) => r.orderId == o.id)) {
      return const Result.fail(
        'This order has a return, so it cannot be undone.',
      );
    }
    o.status = OrderStatus.shipped;
    o.completedAt = null;
    loyaltyTxns.removeWhere(
      (t) => t.type == LoyaltyType.earn && t.orderId == o.id,
    );
    _commit();
    return const Result.ok();
  }

  void cancelOrder(Order o) {
    if (!o.status.isOpen) return;
    o.status = OrderStatus.cancelled;
    _restoreStock(o, MoveType.restore, 'Order #${o.number} cancelled');
    // Points spent on a cancelled order go back to the customer.
    loyaltyTxns.removeWhere(
      (t) => t.type == LoyaltyType.redeem && t.orderId == o.id,
    );
    _commit();
  }

  void _restoreStock(Order o, MoveType type, String note) {
    for (final i in o.items) {
      final p = productById(i.productId);
      if (p != null) _move(p, type, i.qty, note: note, orderId: o.id);
    }
  }

  /// Deleting an open order puts its stock back. A completed order was already
  /// delivered, so by default its stock is not restored (record a return for
  /// that); pass [restoreStock] when it was completed by mistake.
  void deleteOrder(Order o, {bool restoreStock = false}) {
    if (o.status.isOpen ||
        (restoreStock && o.status == OrderStatus.completed)) {
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

  /// What can still be refunded on this order: its total minus every return
  /// that was not rejected.
  double refundableLeft(Order o) {
    final used = returns
        .where((r) => r.orderId == o.id && r.status != ReturnStatus.rejected)
        .fold(0.0, (s, r) => s + r.refund);
    return r2((o.total - used).clamp(0, double.infinity));
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
    // A cent of slack: shares of a discounted total are rounded one by one.
    final left = refundableLeft(order);
    if (refund > left + 0.01) {
      return Result.fail(
        'Only ${peso(left)} can still be refunded on this order.',
      );
    }
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
    _reversePoints(r);
    _commit();
  }

  /// Takes back the share of the points this order earned that matches the
  /// share of its total being refunded. It uses the points actually earned, so
  /// changing the earn rule later cannot make a balance drift, and it never
  /// takes back more than was earned.
  void _reversePoints(ReturnRequest r) {
    final order = orderById(r.orderId);
    if (order == null || order.total <= 0) return;
    final earned = loyaltyTxns
        .where((t) => t.type == LoyaltyType.earn && t.orderId == r.orderId)
        .firstOrNull;
    if (earned == null) return;
    final reversed = -loyaltyTxns
        .where((t) => t.type == LoyaltyType.reversal && t.orderId == r.orderId)
        .fold(0, (s, t) => s + t.points);
    // Work from everything refunded so far, so several small refunds add up
    // to the right points instead of each rounding down to nothing.
    final refunded = returns
        .where(
          (x) => x.orderId == r.orderId && x.status == ReturnStatus.approved,
        )
        .fold(0.0, (s, x) => s + x.refund);
    var target = (earned.points * refunded / order.total).floor();
    if (target > earned.points) target = earned.points;
    final pts = target - reversed;
    if (pts <= 0) return;
    loyaltyTxns.add(
      LoyaltyTxn(
        id: newId('l'),
        phone: earned.phone,
        name: earned.name,
        points: -pts,
        type: LoyaltyType.reversal,
        orderId: r.orderId,
        returnId: r.id,
        note: 'Refund on order #${r.orderNumber}',
      ),
    );
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
      // Older saved data has no returnId, so it is matched by its note.
      loyaltyTxns.removeWhere(
        (t) =>
            t.type == LoyaltyType.reversal &&
            (t.returnId == r.id ||
                (t.returnId == null &&
                    t.orderId == r.orderId &&
                    t.note == 'Refund on order #${r.orderNumber}')),
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

  void applyExpenseEdit(
    Expense e, {
    required String title,
    required String category,
    required double amount,
    required String note,
    required DateTime date,
  }) {
    e
      ..title = title
      ..category = category
      ..amount = amount
      ..note = note
      ..date = date;
    _commit();
  }

  void deleteExpense(Expense e) {
    expenses.removeWhere((x) => x.id == e.id);
    _commit();
  }

  // ---------------------------------------------------------------- loyalty

  void saveLoyaltyConfig() => _commit();

  void setLoyaltyRules({required double earn, required double value}) {
    loyalty
      ..pesoPerPoint = earn
      ..pesoPerPointValue = value;
    _commit();
  }

  void setLoyaltyEnabled(bool on) {
    loyalty.enabled = on;
    _commit();
  }

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
    _storage.remove('${_key}_backup'); // a corrupt-data copy is data too
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
      final monitor = products.firstWhere((p) => p.sku == 'A2G-EL-002');
      final item = ro.items.where((i) => i.productId == monitor.id).first;
      createReturn(
        order: ro,
        qtys: {item: 1},
        reason: 'Defective item',
        note: 'Screen flickers when turned on',
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
