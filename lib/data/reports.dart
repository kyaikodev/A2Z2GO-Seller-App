import '../core/format.dart';
import 'models.dart';
import 'store.dart';

/// A reporting window split into equal buckets (days or months).
class Period {
  final String label;
  final DateTime start; // inclusive
  final DateTime end; // exclusive
  final bool monthly;
  final int buckets;

  Period._(this.label, this.start, this.end, this.monthly, this.buckets);

  factory Period.days(int n, {String? label}) {
    final today = dayStart(DateTime.now());
    final start = today.subtract(Duration(days: n - 1));
    return Period._(
      label ?? 'Last $n days',
      start,
      today.add(const Duration(days: 1)),
      false,
      n,
    );
  }

  factory Period.months(int n, {String? label}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (n - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return Period._(label ?? 'Last $n months', start, end, true, n);
  }

  int bucketOf(DateTime d) {
    if (d.isBefore(start) || !d.isBefore(end)) return -1;
    if (monthly) {
      return (d.year - start.year) * 12 + d.month - start.month;
    }
    return dayStart(d).difference(start).inDays;
  }

  String bucketLabel(int i) {
    if (monthly) {
      final d = DateTime(start.year, start.month + i, 1);
      return monthName(d.month);
    }
    final d = start.add(Duration(days: i));
    return buckets <= 7
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]
        : '${d.day}';
  }
}

class ProductStat {
  final String name;
  int qty = 0;
  double revenue = 0;
  ProductStat(this.name);
}

class Report {
  double gross = 0;
  double discounts = 0;
  double refunds = 0;
  double cogs = 0;
  double stockLoss = 0;
  double expenses = 0;
  int ordersCompleted = 0;
  late List<double> salesSeries; // net sales per bucket
  late List<double> profitSeries; // net profit per bucket
  final Map<String, double> expenseByCategory = {};
  final Map<String, ProductStat> productStats = {};

  double get netSales => r2(gross - discounts - refunds);
  double get grossProfit => r2(netSales - cogs);
  double get netProfit => r2(netSales - cogs - stockLoss - expenses);
  double get avgOrder =>
      ordersCompleted == 0 ? 0 : r2(netSales / ordersCompleted);
  double get margin => netSales <= 0 ? 0 : netProfit / netSales;

  List<ProductStat> get bestSellers {
    final l = productStats.values.where((p) => p.qty > 0).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return l;
  }

  bool get isEmpty =>
      ordersCompleted == 0 && expenses == 0 && stockLoss == 0 && refunds == 0;

  static Report build(AppStore s, Period p) {
    final r = Report();
    final sales = List<double>.filled(p.buckets, 0);
    final cost = List<double>.filled(p.buckets, 0); // cogs + losses + expenses

    for (final o in s.orders) {
      if (o.status != OrderStatus.completed) continue;
      final d = o.completedAt ?? o.createdAt;
      final b = p.bucketOf(d);
      if (b < 0) continue;
      r.gross += o.subtotal;
      r.discounts += o.discount;
      r.cogs += o.cost;
      r.ordersCompleted++;
      sales[b] += o.total;
      cost[b] += o.cost;
      // spread the discount over lines so product revenue adds up
      final ratio = o.subtotal <= 0 ? 1.0 : o.total / o.subtotal;
      for (final i in o.items) {
        final st = r.productStats.putIfAbsent(
          i.productId,
          () => ProductStat(i.name),
        );
        st.qty += i.qty;
        st.revenue += i.lineTotal * ratio;
      }
    }

    for (final ret in s.returns) {
      if (ret.status != ReturnStatus.approved) continue;
      final b = p.bucketOf(ret.resolvedAt ?? ret.createdAt);
      if (b < 0) continue;
      r.refunds += ret.refund;
      sales[b] -= ret.refund;
      if (ret.restock) {
        r.cogs -= ret.cost;
        cost[b] -= ret.cost;
      }
      for (final i in ret.items) {
        final st = r.productStats[i.productId];
        if (st != null) st.qty -= i.qty;
      }
    }

    for (final m in s.moves) {
      if (m.type != MoveType.damaged) continue;
      final b = p.bucketOf(m.at);
      if (b < 0) continue;
      final loss = r2(-m.delta * m.unitCost);
      r.stockLoss += loss;
      cost[b] += loss;
    }

    for (final e in s.expenses) {
      final b = p.bucketOf(e.date);
      if (b < 0) continue;
      r.expenses += e.amount;
      cost[b] += e.amount;
      r.expenseByCategory.update(
        e.category,
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    r.gross = r2(r.gross);
    r.discounts = r2(r.discounts);
    r.refunds = r2(r.refunds);
    r.cogs = r2(r.cogs);
    r.stockLoss = r2(r.stockLoss);
    r.expenses = r2(r.expenses);
    r.salesSeries = sales.map(r2).toList();
    r.profitSeries = List.generate(p.buckets, (i) => r2(sales[i] - cost[i]));
    return r;
  }
}

/// Live counts that don't depend on a date range.
class Snapshot {
  final int products;
  final int lowStock;
  final int outOfStock;
  final int pendingOrders;
  final int openOrders;
  final int totalOrders;
  final int openReturns;
  final int pointsOutstanding;
  final int pointsEarned;
  final int pointsRedeemed;
  final double stockValueCost;
  final double stockValueRetail;

  Snapshot._(
    this.products,
    this.lowStock,
    this.outOfStock,
    this.pendingOrders,
    this.openOrders,
    this.totalOrders,
    this.openReturns,
    this.pointsOutstanding,
    this.pointsEarned,
    this.pointsRedeemed,
    this.stockValueCost,
    this.stockValueRetail,
  );

  factory Snapshot.of(AppStore s) {
    var low = 0, out = 0;
    var vc = 0.0, vr = 0.0;
    for (final p in s.products) {
      if (!p.active) continue;
      if (p.isOut) {
        out++;
      } else if (p.isLow) {
        low++;
      }
      vc += p.cost * p.stock;
      vr += p.price * p.stock;
    }
    var earned = 0, redeemed = 0, balance = 0;
    for (final t in s.loyaltyTxns) {
      balance += t.points;
      if (t.type == LoyaltyType.earn) earned += t.points;
      if (t.type == LoyaltyType.redeem) redeemed += -t.points;
    }
    return Snapshot._(
      s.products.length,
      low,
      out,
      s.orders.where((o) => o.status == OrderStatus.pending).length,
      s.orders.where((o) => o.status.isOpen).length,
      s.orders.length,
      s.returns.where((r) => r.status == ReturnStatus.requested).length,
      balance,
      earned,
      redeemed,
      r2(vc),
      r2(vr),
    );
  }
}
