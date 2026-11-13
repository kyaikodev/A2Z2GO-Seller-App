import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/reports.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import '../orders/order_form_screen.dart';
import '../products/product_detail_screen.dart';
import '../products/product_form_screen.dart';
import '../shell.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends StatelessWidget {
  final void Function(int tab) onGoTab;
  final void Function(int ordersTab) onGoOrders;
  const DashboardScreen({
    super.key,
    required this.onGoTab,
    required this.onGoOrders,
  });

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final period = Period.days(7);
    final rep = store.report(period);
    final today = store.report(Period.days(1));
    final snap = store.snapshot;
    final low = store.lowStock;

    final now = DateTime.now();
    final ordersToday = store.orders
        .where(
          (o) =>
              o.createdAt.year == now.year &&
              o.createdAt.month == now.month &&
              o.createdAt.day == now.day &&
              o.status != OrderStatus.cancelled,
        )
        .length;
    int count(bool Function(Order) test) => store.orders.where(test).length;
    final toShip = count(
      (o) => o.status == OrderStatus.pending || o.status == OrderStatus.packed,
    );
    final shipping = count((o) => o.status == OrderStatus.shipped);
    final cancelled = count((o) => o.status == OrderStatus.cancelled);

    final hasProducts = store.products.isNotEmpty;
    final hasStock = store.products.any((p) => p.stock > 0);
    final hasOrders = store.orders.isNotEmpty;
    final setupDone = hasProducts && hasStock && hasOrders;

    final account = store.account;
    final initial = (account.storeName.isEmpty ? 'S' : account.storeName[0])
        .toUpperCase();

    return Scaffold(
      backgroundColor: Brand.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---- Red header: shop + today's numbers
          Container(
            decoration: const BoxDecoration(
              color: Brand.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 16,
              16,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Brand.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_greeting()}, ${account.ownerName.split(' ').first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Net sales today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    peso(today.netSales),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$ordersToday new order${ordersToday == 1 ? '' : 's'} today  ·  ${peso(rep.netProfit, decimals: false)} profit this week',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // ---- Order status tiles
                _Panel(
                  title: 'Orders',
                  index: 0,
                  action: 'View all',
                  onAction: () => onGoOrders(0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CountTile(
                        '$toShip',
                        'To Ship',
                        icon: Icons.inventory_2_outlined,
                        highlight: toShip > 0,
                        onTap: () => onGoOrders(1),
                      ),
                      _CountTile(
                        '$shipping',
                        'Shipping',
                        icon: Icons.local_shipping_outlined,
                        onTap: () => onGoOrders(2),
                      ),
                      _CountTile(
                        '$cancelled',
                        'Cancelled',
                        icon: Icons.cancel_outlined,
                        onTap: () => onGoOrders(4),
                      ),
                      _CountTile(
                        '${snap.openReturns}',
                        'Returns',
                        icon: Icons.assignment_return_outlined,
                        highlight: snap.openReturns > 0,
                        onTap: () => onGoOrders(5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ---- Quick actions (the only buttons on this screen)
                _Panel(
                  title: 'Quick actions',
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _push(context, const ProductFormScreen()),
                          icon: const Icon(Icons.add_box_outlined, size: 20),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Add product'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _push(context, const OrderFormScreen()),
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('New order'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!setupDone) ...[
                  const SizedBox(height: 12),
                  _GetStarted(
                    hasProducts: hasProducts,
                    hasStock: hasStock,
                    hasOrders: hasOrders,
                    onAddProduct: () =>
                        _push(context, const ProductFormScreen()),
                    onGoProducts: () => onGoTab(Tabs.products),
                    onNewOrder: () => _push(context, const OrderFormScreen()),
                  ),
                ],
                const SizedBox(height: 12),
                _Panel(
                  title: 'Sales · last 7 days',
                  index: 3,
                  action: 'Insights',
                  onAction: () => onGoTab(Tabs.insights),
                  child: BarChart(
                    values: rep.salesSeries,
                    labels: List.generate(period.buckets, period.bucketLabel),
                    tooltips: List.generate(period.buckets, period.bucketTitle),
                  ),
                ),
                const SizedBox(height: 12),
                _Panel(
                  title: 'Stock alerts',
                  index: 4,
                  action: low.isEmpty ? null : 'See all',
                  onAction: () => onGoTab(Tabs.products),
                  child: low.isEmpty
                      ? Text(
                          hasProducts
                              ? 'All products are well stocked.'
                              : 'Add products to see stock alerts here.',
                          style: const TextStyle(color: Brand.muted),
                        )
                      : Column(
                          children: [
                            for (final p in low.take(4))
                              InfoTile(
                                card: false,
                                leading: ProductThumb(
                                  path: p.imagePath,
                                  size: 40,
                                ),
                                title: p.name,
                                trailing: StatusChip(
                                  p.isOut ? 'Out of stock' : '${p.stock} left',
                                  p.isOut ? Brand.bad : Brand.warn,
                                ),
                                onTap: () => _push(
                                  context,
                                  ProductDetailScreen(productId: p.id),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White section with a title and an optional text link on the right.
class _Panel extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;
  final int index;
  const _Panel({
    required this.title,
    this.action,
    this.onAction,
    required this.child,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(index: index, child: _card(context));
  }

  Widget _card(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(Rd.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Brand.navy,
                        ),
                      ),
                    ),
                    if (action != null)
                      Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: Brand.muted,
                        semanticLabel: action,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  final bool highlight;
  final VoidCallback onTap;
  const _CountTile(
    this.count,
    this.label, {
    required this.icon,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (highlight ? Brand.primary : Brand.muted).withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: highlight ? Brand.primary : Brand.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Brand.primary : Brand.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GetStarted extends StatelessWidget {
  final bool hasProducts;
  final bool hasStock;
  final bool hasOrders;
  final VoidCallback onAddProduct;
  final VoidCallback onGoProducts;
  final VoidCallback onNewOrder;

  const _GetStarted({
    required this.hasProducts,
    required this.hasStock,
    required this.hasOrders,
    required this.onAddProduct,
    required this.onGoProducts,
    required this.onNewOrder,
  });

  @override
  Widget build(BuildContext context) {
    Widget step(bool done, String title, String sub, VoidCallback onTap) {
      return InfoTile(
        card: false,
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Brand.good : Brand.muted,
        ),
        title: title,
        subtitle: sub,
        trailing: done ? null : const Icon(Icons.chevron_right),
        onTap: done ? null : onTap,
      );
    }

    return _Panel(
      title: 'Get your shop going',
      index: 2,
      child: Column(
        children: [
          step(
            hasProducts,
            'Add your first product',
            'Name, price, cost and photo',
            onAddProduct,
          ),
          step(
            hasStock,
            'Put stock on the shelf',
            'Open a product and tap “Stock in”',
            onGoProducts,
          ),
          step(
            hasOrders,
            'Record your first order',
            'Sales, profit and graphs build from this',
            onNewOrder,
          ),
        ],
      ),
    );
  }
}
