import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/reports.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _range = 0;

  Period get _period => switch (_range) {
    0 => Period.days(7, label: 'Last 7 days'),
    1 => Period.days(30, label: 'Last 30 days'),
    _ => Period.months(12, label: 'Last 12 months'),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final period = _period;
    final rep = store.report(period);
    final snap = store.snapshot;
    final labels = List.generate(period.buckets, period.bucketLabel);
    final tooltips = List.generate(period.buckets, period.bucketTitle);
    final best = rep.bestSellers.take(5).toList();
    final maxRev = best.isEmpty ? 1.0 : best.first.revenue;
    final expenses = rep.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Pill('7 days', _range == 0, () => setState(() => _range = 0)),
                Pill('30 days', _range == 1, () => setState(() => _range = 1)),
                Pill(
                  '12 months',
                  _range == 2,
                  () => setState(() => _range = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (store.orders.isEmpty && store.expenses.isEmpty)
            const SectionCard(
              child: Text(
                'No data yet. Sales, profit and charts show up once you complete an order or add an expense.',
                style: TextStyle(color: Brand.muted, height: 1.4),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Net sales',
                    value: peso(rep.netSales),
                    icon: Icons.payments_outlined,
                    color: Brand.good,
                    sub: '${rep.ordersCompleted} orders',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Net profit',
                    value: peso(rep.netProfit),
                    icon: Icons.savings_outlined,
                    color: rep.netProfit >= 0 ? Brand.good : Brand.bad,
                    sub: rep.netSales > 0
                        ? '${(rep.margin * 100).toStringAsFixed(0)}% margin'
                        : 'No sales yet',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Sales · ${period.label.toLowerCase()}',
              child: BarChart(
                values: rep.salesSeries,
                labels: labels,
                tooltips: tooltips,
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Profit · ${period.label.toLowerCase()}',
              child: BarChart(
                values: rep.profitSeries,
                labels: labels,
                tooltips: tooltips,
                color: Brand.good,
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Profit statement',
              child: Column(
                children: [
                  _line('Gross sales', peso(rep.gross)),
                  _line('Discounts given', '-${peso(rep.discounts)}'),
                  _line('Refunds', '-${peso(rep.refunds)}'),
                  const Divider(height: 18),
                  _line('Net sales', peso(rep.netSales), bold: true),
                  _line('Cost of goods sold', '-${peso(rep.cogs)}'),
                  _line('Damaged / lost stock', '-${peso(rep.stockLoss)}'),
                  _line('Expenses', '-${peso(rep.expenses)}'),
                  const Divider(height: 18),
                  _line(
                    'Net profit',
                    peso(rep.netProfit),
                    bold: true,
                    color: rep.netProfit >= 0 ? Brand.good : Brand.bad,
                  ),
                  if (rep.ordersCompleted > 0) ...[
                    const SizedBox(height: 6),
                    _line('Average order', peso(rep.avgOrder), muted: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Best sellers',
              child: best.isEmpty
                  ? const Text(
                      'No completed sales in this period.',
                      style: TextStyle(color: Brand.muted),
                    )
                  : Column(
                      children: [
                        for (final p in best)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${p.qty} sold · ${peso(p.revenue, decimals: false)}',
                                      style: const TextStyle(
                                        color: Brand.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (p.revenue / maxRev).clamp(
                                      0.02,
                                      1.0,
                                    ),
                                    minHeight: 7,
                                    backgroundColor: Brand.line,
                                    color: Brand.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Expenses by category',
              child: expenses.isEmpty
                  ? const Text(
                      'No expenses recorded in this period.',
                      style: TextStyle(color: Brand.muted),
                    )
                  : Column(
                      children: [
                        for (final e in expenses)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key)),
                                Text(
                                  peso(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
          if (store.products.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Inventory value',
              child: Row(
                children: [
                  Expanded(
                    child: _stockFact('At cost', peso(snap.stockValueCost)),
                  ),
                  Expanded(
                    child: _stockFact(
                      'At selling price',
                      peso(snap.stockValueRetail),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockFact(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: Brand.muted, fontSize: 13)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          v,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _line(
    String l,
    String v, {
    bool bold = false,
    bool muted = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l,
            style: TextStyle(
              color: muted ? Brand.muted : Brand.navy,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          v,
          style: TextStyle(
            color: color ?? (muted ? Brand.muted : Brand.navy),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    ),
  );
}
