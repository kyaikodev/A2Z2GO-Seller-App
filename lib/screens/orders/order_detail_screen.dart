import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import 'orders_screen.dart' show statusColor, returnColor;
import 'return_detail_screen.dart';
import 'return_form_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final o = store.orderById(orderId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Order not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final returns = store.returns.where((r) => r.orderId == o.id).toList();
    final next = o.status.next;
    final canReturn =
        o.status == OrderStatus.completed &&
        o.items.any((i) => store.returnableQty(o, i.productId) > 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${o.number}'),
        actions: [
          IconButton(
            tooltip: 'Delete order',
            icon: const Icon(Icons.delete_outline, color: Brand.bad),
            onPressed: () async {
              final msg = o.status.isOpen
                  ? 'The order is removed and its items go back into stock.'
                  : o.status == OrderStatus.completed
                  ? 'The sale is removed from your sales and profit. Stock is not restored, since the items were delivered. Record a return if goods came back.'
                  : 'The order is removed from your records.';
              final ok = await confirmDialog(
                context,
                title: 'Delete order #${o.number}?',
                message: msg,
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok && context.mounted) {
                store.deleteOrder(o);
                Navigator.pop(context);
                showMsg(context, 'Order deleted');
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: (next == null && !o.status.isOpen && !canReturn)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Brand.line)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (next != null)
                      FilledButton.icon(
                        onPressed: () {
                          store.advanceOrder(o);
                          showMsg(
                            context,
                            next == OrderStatus.completed
                                ? 'Order completed. Sale recorded.'
                                : 'Marked as ${next.label.toLowerCase()}',
                          );
                        },
                        icon: Icon(
                          next == OrderStatus.completed
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                        ),
                        label: Text(switch (next) {
                          OrderStatus.packed => 'Mark as packed',
                          OrderStatus.shipped => 'Mark as shipped',
                          _ => 'Mark as completed',
                        }),
                      ),
                    if (o.status.isOpen) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Cancel order #${o.number}?',
                            message: 'The items go back into stock.',
                            confirmLabel: 'Cancel order',
                            destructive: true,
                          );
                          if (ok && context.mounted) {
                            store.cancelOrder(o);
                            showMsg(context, 'Order cancelled');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Brand.bad,
                          side: const BorderSide(color: Brand.bad),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel order'),
                      ),
                    ],
                    if (canReturn)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReturnFormScreen(orderId: o.id),
                          ),
                        ),
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('Record a return'),
                      ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(o.status.label, statusColor(o.status)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dateTimeFmt(o.createdAt),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Brand.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        o.displayCustomer,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (o.customerPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_iphone, color: Brand.muted),
                        const SizedBox(width: 8),
                        Text(prettyPhone(o.customerPhone)),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: Brand.muted),
                      const SizedBox(width: 8),
                      Text(o.payment),
                    ],
                  ),
                ),
                if (o.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Note: ${o.note}',
                      style: const TextStyle(color: Brand.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Items',
            child: Column(
              children: [
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i.qty} × ${i.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(peso(i.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: 22),
                _row('Subtotal', peso(o.subtotal)),
                if (o.discount > 0) _row('Discount', '-${peso(o.discount)}'),
                _row('Total', peso(o.total), big: true),
                const SizedBox(height: 6),
                _row('Your cost', peso(o.cost), muted: true),
                _row(
                  'Profit on this order',
                  peso(o.total - o.cost),
                  muted: true,
                ),
              ],
            ),
          ),
          if (returns.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Returns',
              child: Column(
                children: [
                  for (final r in returns)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${r.qty} item${r.qty == 1 ? '' : 's'} · ${r.reason}',
                      ),
                      subtitle: Text(peso(r.refund)),
                      trailing: StatusChip(
                        r.status.label,
                        returnColor(r.status),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReturnDetailScreen(returnId: r.id),
                        ),
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

  Widget _row(String l, String v, {bool big = false, bool muted = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l,
                style: TextStyle(
                  color: muted ? Brand.muted : Brand.navy,
                  fontSize: big ? 16 : 14,
                  fontWeight: big ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              v,
              style: TextStyle(
                color: big
                    ? Brand.primary
                    : muted
                    ? Brand.muted
                    : Brand.navy,
                fontSize: big ? 19 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
