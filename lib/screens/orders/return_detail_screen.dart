import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import 'orders_screen.dart' show returnColor;

class ReturnDetailScreen extends StatelessWidget {
  final String returnId;
  const ReturnDetailScreen({super.key, required this.returnId});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final r = store.returns.where((e) => e.id == returnId).firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.assignment_return_outlined,
          title: 'Return not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Return · Order #${r.orderNumber}'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Brand.bad),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete this return?',
                message: r.status == ReturnStatus.approved
                    ? 'Deleting this undoes the refund, the items it put back in stock, and the points it reversed.'
                    : 'The return record is removed.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok && context.mounted) {
                store.deleteReturn(r);
                Navigator.pop(context);
                showMsg(context, 'Return deleted');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(r.status.label, returnColor(r.status)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dateTimeFmt(r.createdAt),
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
                Text(
                  r.reason,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (r.customerName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      r.customerName,
                      style: const TextStyle(color: Brand.muted),
                    ),
                  ),
                if (r.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(r.note),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Items returned',
            child: Column(
              children: [
                for (final i in r.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${i.qty} × ${i.name}')),
                        Text(peso(i.unitPrice * i.qty)),
                      ],
                    ),
                  ),
                const Divider(height: 22),
                Row(
                  children: [
                    const Text(
                      'Refund',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      peso(r.refund),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Brand.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.restock
                      ? 'Items go back into stock when approved.'
                      : 'Items will not go back into stock.',
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (r.status == ReturnStatus.requested) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Approve and refund ${peso(r.refund)}?',
                  message:
                      'This reduces your sales${r.restock ? ' and returns the items to stock' : ''}.',
                  confirmLabel: 'Approve',
                );
                if (ok && context.mounted) {
                  store.approveReturn(r);
                  showMsg(context, 'Return approved and refunded');
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Approve and refund'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Reject this return?',
                  message: 'Nothing is refunded and stock is unchanged.',
                  confirmLabel: 'Reject',
                  destructive: true,
                );
                if (ok && context.mounted) {
                  store.rejectReturn(r);
                  showMsg(context, 'Return rejected');
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Brand.bad,
                side: const BorderSide(color: Brand.bad),
              ),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
            ),
          ],
        ],
      ),
    );
  }
}
