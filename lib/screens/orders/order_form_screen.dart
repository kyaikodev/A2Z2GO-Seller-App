import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart' show AppStore;
import '../../widgets/common.dart';
import '../../widgets/pick_field.dart';
import '../../widgets/scope.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController();
  final _note = TextEditingController();
  final Map<String, int> _qty = {}; // productId -> qty
  String _payment = paymentMethods.first;
  bool _dirty = false; // something was typed or changed
  bool _usePoints = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _discount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double _subtotal() {
    final store = context.store;
    var s = 0.0;
    for (final e in _qty.entries) {
      final p = store.productById(e.key);
      if (p != null) s += p.price * e.value;
    }
    return r2(s);
  }

  /// The most points this customer can spend on this order: what they have,
  /// but never more than the amount still to pay.
  int _maxPoints(AppStore store) {
    final phone = normalizePhone(_phone.text.trim());
    final worth = store.loyalty.pesoPerPointValue;
    if (!store.loyalty.enabled || phone == null || worth <= 0) return 0;
    final room = r2(
      (_subtotal() - parseMoney(_discount.text)).clamp(0, double.infinity),
    );
    final cap = (room / worth).floor();
    final have = store.balanceOf(phone);
    return have < cap ? have : cap;
  }

  Future<void> _addProducts() async {
    final store = context.store;
    final available =
        store.products
            .where((p) => p.active && p.stock > 0 && !_qty.containsKey(p.id))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (available.isEmpty) {
      showMsg(
        context,
        store.products.isEmpty
            ? 'Add a product first (Products tab).'
            : 'No more products with stock to add.',
        error: true,
      );
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ProductPicker(products: available),
    );
    if (picked != null) {
      setState(() {
        _dirty = true;
        _qty[picked.id] = 1;
      });
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = context.store;
    final phoneRaw = _phone.text.trim();
    String phone = '';
    if (phoneRaw.isNotEmpty) {
      final n = normalizePhone(phoneRaw);
      if (n == null) {
        showMsg(context, 'That phone number does not look right.', error: true);
        return;
      }
      phone = n;
    }
    final lines = <Product, int>{};
    for (final e in _qty.entries) {
      final p = store.productById(e.key);
      if (p != null) lines[p] = e.value;
    }
    final res = store.createOrder(
      customerName: _name.text,
      customerPhone: phone,
      lines: lines,
      discount: parseMoney(_discount.text),
      payment: _payment,
      note: _note.text,
      redeemPoints: _usePoints ? _maxPoints(store) : 0,
    );
    if (!res.ok) {
      showMsg(context, res.error!, error: true);
      return;
    }
    Navigator.pop(context);
    showMsg(context, 'Order created. Stock has been reserved.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final subtotal = _subtotal();
    final discount = parseMoney(_discount.text);
    final maxPoints = _maxPoints(store);
    final points = _usePoints ? maxPoints : 0;
    final pointsValue = r2(points * store.loyalty.pesoPerPointValue);
    final total = r2(
      (subtotal - discount - pointsValue).clamp(0, double.infinity),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New order')),
      bottomNavigationBar: FormActionBar(
        child: FilledButton(
          onPressed: _save,
          child: const Text('Create order'),
        ),
      ),
      body: Form(
        key: _form,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await confirmDialog(
            context,
            title: 'Discard this order?',
            message: 'What you entered has not been saved.',
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
            destructive: true,
          );
          if (leave && context.mounted) Navigator.pop(context);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SectionCard(
              title: 'Customer',
              child: Column(
                children: [
                  // Past customers are offered in a list; a new name is added
                  // there too. Picking one fills in their mobile number.
                  PickOrAddField(
                    controller: _name,
                    label: 'Name',
                    noun: 'customer',
                    icon: Icons.person_outline,
                    options: store.customerPhones.keys.toList()..sort(),
                    onPicked: (v) {
                      final known = store.customerPhones[v] ?? '';
                      if (known.isNotEmpty && _phone.text.trim().isEmpty) {
                        setState(() => _phone.text = known);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Mobile (optional)',
                      helperText: store.loyalty.enabled
                          ? 'Add it so this customer earns loyalty points'
                          : null,
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Items',
              trailing: TextButton.icon(
                onPressed: _addProducts,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              child: _qty.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No items yet. Tap “Add” to pick products.',
                        style: TextStyle(color: Brand.muted),
                      ),
                    )
                  : Column(
                      children: [
                        for (final e in _qty.entries.toList())
                          _line(store.productById(e.key), e.value),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _payment,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: [
                      for (final m in paymentMethods)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => _payment = v ?? _payment),
                  ),
                  if (maxPoints > 0)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Use $maxPoints points'),
                      subtitle: Text(
                        'Takes ${peso(r2(maxPoints * store.loyalty.pesoPerPointValue))} off this order',
                      ),
                      value: _usePoints,
                      activeThumbColor: Brand.primary,
                      onChanged: (v) => setState(() => _usePoints = v),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Discount (optional)',
                      prefixText: '₱ ',
                    ),
                    validator: (v) {
                      final base = moneyValidator(v, required: false);
                      if (base != null) return base;
                      if (parseMoney(v ?? '') > subtotal) {
                        return 'More than the order total';
                      }
                      return null;
                    },
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
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                children: [
                  _sum('Subtotal', peso(subtotal)),
                  if (discount > 0) _sum('Discount', '-${peso(discount)}'),
                  if (points > 0)
                    _sum('Points used ($points)', '-${peso(pointsValue)}'),
                  const Divider(height: 20),
                  _sum('Total', peso(total), big: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sum(String l, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          l,
          style: TextStyle(
            fontSize: big ? 17 : 14,
            fontWeight: big ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 20 : 14,
            fontWeight: FontWeight.w800,
            color: big ? Brand.primary : Brand.navy,
          ),
        ),
      ],
    ),
  );

  Widget _line(Product? p, int qty) {
    if (p == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ProductThumb(path: p.imagePath, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${peso(p.price)} · ${p.stock} in stock',
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove one',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => setState(() {
              if (qty <= 1) {
                _qty.remove(p.id);
              } else {
                _qty[p.id] = qty - 1;
              }
            }),
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
            tooltip: 'Add one',
            icon: const Icon(Icons.add_circle_outline, color: Brand.primary),
            onPressed: qty >= p.stock
                ? () =>
                      showMsg(context, 'Only ${p.stock} in stock.', error: true)
                : () => setState(() => _qty[p.id] = qty + 1),
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  final List<Product> products;
  const _ProductPicker({required this.products});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(_q) ||
              p.sku.toLowerCase().contains(_q),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No match'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return ListTile(
                          leading: ProductThumb(path: p.imagePath, size: 44),
                          title: Text(p.name),
                          subtitle: Text('${p.stock} in stock'),
                          trailing: Text(
                            peso(p.price),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
