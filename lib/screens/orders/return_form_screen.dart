import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';

/// Records a customer return against a completed order.
class ReturnFormScreen extends StatefulWidget {
  final String orderId;
  const ReturnFormScreen({super.key, required this.orderId});

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _refund = TextEditingController();
  final Map<int, int> _qty = {}; // item index -> qty
  String _reason = returnReasons.first;
  bool _restock = true;
  bool _refundEdited = false;

  @override
  void dispose() {
    _note.dispose();
    _refund.dispose();
    super.dispose();
  }

  Map<OrderItem, int> _chosen(Order o) => {
    for (final e in _qty.entries)
      if (e.value > 0 && e.key < o.items.length) o.items[e.key]: e.value,
  };

  void _recalc(Order o) {
    if (_refundEdited) return;
    final amt = context.store.suggestedRefund(o, _chosen(o));
    _refund.text = amt == 0 ? '' : amt.toStringAsFixed(2);
  }

  void _save(Order o) {
    if (!_form.currentState!.validate()) return;
    final res = context.store.createReturn(
      order: o,
      qtys: _chosen(o),
      reason: _reason,
      note: _note.text,
      refund: parseMoney(_refund.text),
      restock: _restock,
    );
    if (!res.ok) {
      showMsg(context, res.error!, error: true);
      return;
    }
    Navigator.pop(context);
    showMsg(context, 'Return recorded. Approve it to refund.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final o = store.orderById(widget.orderId);
    if (o == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: Text('Return · Order #${o.number}')),
      bottomNavigationBar: FormActionBar(
        child: FilledButton(
          onPressed: () => _save(o),
          child: const Text('Record return'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SectionCard(
              title: 'What is being returned?',
              child: Column(
                children: [
                  for (var idx = 0; idx < o.items.length; idx++)
                    _itemRow(o, idx),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: [
                      for (final r in returnReasons)
                        DropdownMenuItem(value: r, child: Text(r)),
                    ],
                    onChanged: (v) => setState(() => _reason = v ?? _reason),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _refund,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => _refundEdited = true,
                    decoration: const InputDecoration(
                      labelText: 'Refund amount',
                      prefixText: '₱ ',
                      helperText:
                          'Filled in from the items; change it if needed',
                    ),
                    validator: (v) => moneyValidator(v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Put items back in stock'),
                    subtitle: const Text(
                      'Turn off if the items are damaged and cannot be resold',
                    ),
                    value: _restock,
                    activeThumbColor: Brand.primary,
                    onChanged: (v) => setState(() => _restock = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(Order o, int idx) {
    final store = context.store;
    final item = o.items[idx];
    final max = store.returnableQty(o, item.productId);
    final qty = _qty[idx] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  max > 0
                      ? 'Bought ${item.qty} · can return up to $max'
                      : 'Already fully returned',
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: qty <= 0
                ? null
                : () {
                    setState(() => _qty[idx] = qty - 1);
                    _recalc(o);
                  },
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add_circle_outline,
              color: qty >= max ? Brand.line : Brand.primary,
            ),
            onPressed: qty >= max
                ? null
                : () {
                    setState(() => _qty[idx] = qty + 1);
                    _recalc(o);
                  },
          ),
        ],
      ),
    );
  }
}
