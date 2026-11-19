import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'return_detail_screen.dart';

Color statusColor(OrderStatus s) => switch (s) {
  OrderStatus.pending => Brand.warn,
  OrderStatus.packed => Brand.info,
  OrderStatus.shipped => const Color(0xFF7A4FD6),
  OrderStatus.completed => Brand.good,
  OrderStatus.cancelled => Brand.muted,
};

Color returnColor(ReturnStatus s) => switch (s) {
  ReturnStatus.requested => Brand.warn,
  ReturnStatus.approved => Brand.good,
  ReturnStatus.rejected => Brand.muted,
};

/// Tab order: All, To Ship, Shipping, Completed, Cancelled, Returns.
class OrdersScreen extends StatefulWidget {
  /// Home tiles set this to open a specific tab.
  final ValueNotifier<int>? jumpTo;
  const OrdersScreen({super.key, this.jumpTo});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  static const _returnsTab = 5;
  final _search = TextEditingController();
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void initState() {
    super.initState();
    widget.jumpTo?.addListener(_jump);
  }

  void _jump() => _tabs.animateTo(widget.jumpTo!.value);

  @override
  void dispose() {
    widget.jumpTo?.removeListener(_jump);
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _new() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const OrderFormScreen()),
  );

  bool _matches(int tab, Order o) => switch (tab) {
    1 => o.status == OrderStatus.pending || o.status == OrderStatus.packed,
    2 => o.status == OrderStatus.shipped,
    3 => o.status == OrderStatus.completed,
    4 => o.status == OrderStatus.cancelled,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final toShip = store.orders
        .where(
          (o) =>
              o.status == OrderStatus.pending || o.status == OrderStatus.packed,
        )
        .length;
    final openReturns = store.returns
        .where((r) => r.status == ReturnStatus.requested)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'New order',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _new,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            const Tab(text: 'All'),
            Tab(text: toShip > 0 ? 'To Ship ($toShip)' : 'To Ship'),
            const Tab(text: 'Shipping'),
            const Tab(text: 'Completed'),
            const Tab(text: 'Cancelled'),
            Tab(text: openReturns > 0 ? 'Returns ($openReturns)' : 'Returns'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search orders',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (var t = 0; t < _returnsTab; t++) _ordersTab(context, t),
                _returnsList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersTab(BuildContext context, int tab) {
    final store = context.store;
    if (store.orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        message: 'Record an order to track it from pending to completed.',
        actionLabel: 'Create an order',
        onAction: _new,
      );
    }
    final q = _search.text.trim().toLowerCase();
    final list = store.orders.where((o) {
      if (!_matches(tab, o)) return false;
      if (q.isEmpty) return true;
      return o.number.toString().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          phoneMatches(o.customerPhone, q);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No orders here',
        message: 'Orders with this status appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => FadeSlideIn(
        index: i,
        animate: i < 6,
        child: _OrderCard(order: list[i]),
      ),
    );
  }

  Widget _returnsList(BuildContext context) {
    final store = context.store;
    final q = _search.text.trim().toLowerCase();
    final list = store.returns.where((r) {
      if (q.isEmpty) return true;
      return r.orderNumber.toString().contains(q) ||
          r.customerName.toLowerCase().contains(q) ||
          phoneMatches(r.customerPhone, q);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_return_outlined,
        title: 'No returns',
        message: 'Open a completed order and tap “Record a return” when a customer sends something back.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = list[i];
        return InfoTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReturnDetailScreen(returnId: r.id),
            ),
          ),
          title: 'Order #${r.orderNumber} · ${r.reason}',
          subtitle:
              '${dateFmt(r.createdAt)} · ${r.qty} item${r.qty == 1 ? '' : 's'}',
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                peso(r.refund),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              StatusChip(r.status.label, returnColor(r.status)),
            ],
          ),
        );
      },
    );
  }
}

/// One order: who bought, what, the total, and one next-step button.
class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final store = context.store;
    final next = o.status.next;
    final first = o.items.isEmpty ? null : o.items.first;
    final photo = first == null ? null : store.productById(first.productId);
    final more = o.items.length - 1;
    final label = switch (next) {
      OrderStatus.packed => 'Pack order',
      OrderStatus.shipped => 'Ship order',
      OrderStatus.completed => 'Mark completed',
      _ => null,
    };
    final name = o.displayCustomer;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.md),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Brand.tint,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Brand.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '#${o.number} · ${dateTimeShort(o.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Brand.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(o.status.label, statusColor(o.status)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ProductThumb(
                    path: photo?.imagePath,
                    size: 52,
                    category: photo?.category,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first?.name ?? 'Order',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          more > 0
                              ? '${o.itemCount} items · +$more more product${more == 1 ? '' : 's'}'
                              : '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Brand.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(color: Brand.muted, fontSize: 12),
                        ),
                        Text(
                          peso(o.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        store.advanceOrder(o);
                        final done = next == OrderStatus.completed;
                        showMsg(
                          context,
                          done
                              ? 'Order completed. Sale recorded.'
                              : 'Marked as ${next!.label.toLowerCase()}',
                          actionLabel: done ? 'Undo' : null,
                          onAction: done ? () => store.undoCompletion(o) : null,
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: const TextStyle(
                          fontFamily: appFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(label),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
