import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import '../buyer/share_sheet.dart';
import 'product_form_screen.dart';
import 'proof_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final p = store.productById(productId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Product not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final history = store.movesFor(p.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(productId: p.id),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete product',
                  style: TextStyle(color: Brand.bad),
                ),
              ),
            ],
            onSelected: (_) async {
              if (store.productInUse(p)) {
                // Deleting it now would strand an open order, so offer to hide it.
                final hide = await confirmDialog(
                  context,
                  title: '${p.name} is still in use',
                  message: 'An open order or a return waiting for a decision uses this product, so it cannot be deleted yet. Hide it instead? Hidden products cannot be added to new orders.',
                  confirmLabel: 'Hide product',
                );
                if (hide && context.mounted) {
                  p.active = false;
                  store.updateProduct(p);
                  showMsg(context, 'Product hidden');
                }
                return;
              }
              final ok = await confirmDialog(
                context,
                title: 'Delete ${p.name}?',
                message: 'This removes the product and its stock history. Past orders keep their own record of what was sold.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok && context.mounted) {
                store.deleteProduct(p);
                Navigator.pop(context);
                showMsg(context, 'Product deleted');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductThumb(
                        path: p.imagePath,
                        size: 96,
                        category: p.category,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Brand.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.sku} · ${p.category}',
                              style: const TextStyle(color: Brand.muted),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              peso(p.price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Brand.primary,
                              ),
                            ),
                            if (!p.active)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: StatusChip('Hidden', Brand.muted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ExpandableText(
                      p.description,
                      style: const TextStyle(color: Brand.muted, height: 1.4),
                    ),
                  ],
                  const Divider(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Fact(
                        'In stock',
                        '${p.stock}',
                        color: p.isOut
                            ? Brand.bad
                            : p.isLow
                            ? Brand.warn
                            : Brand.good,
                      ),
                      // A cost of zero means it was never entered: do not show a
                      // made-up 100% margin.
                      _Fact('Cost', p.cost > 0 ? peso(p.cost) : 'Not set'),
                      _Fact(
                        'Margin',
                        p.cost > 0
                            ? '${(p.margin * 100).toStringAsFixed(0)}%'
                            : '—',
                      ),
                      _Fact(
                        'Stock value',
                        peso(p.stock * p.cost, decimals: false),
                      ),
                    ],
                  ),
                  if (p.isOut || p.isLow)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        p.isOut
                            ? 'Out of stock. Add stock to sell it again.'
                            : 'Running low (alert at ${p.lowStockAt}).',
                        style: TextStyle(
                          color: p.isOut ? Brand.bad : Brand.warn,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ActionBtn(
                Icons.add_box_outlined,
                'Stock in',
                () => showStockSheet(context, p, MoveType.stockIn),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                Icons.outbox_outlined,
                'Stock out',
                () => showStockSheet(context, p, MoveType.stockOut),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                Icons.heart_broken_outlined,
                'Damaged',
                () => showStockSheet(context, p, MoveType.damaged),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                Icons.fact_check_outlined,
                'Count',
                () => showStockSheet(context, p, MoveType.adjust),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Buyer page',
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                InfoTile(
                  card: false,
                  leading: const Icon(
                    Icons.forum_outlined,
                    color: Brand.primary,
                  ),
                  title: 'Social proof',
                  subtitle: p.posts.isEmpty
                      ? 'Add Facebook, Instagram or TikTok links and comments'
                      : '${p.posts.length} link${p.posts.length == 1 ? '' : 's'} · ${p.commentCount} comment${p.commentCount == 1 ? '' : 's'}',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProofScreen(productId: p.id),
                    ),
                  ),
                ),
                InfoTile(
                  card: false,
                  leading: Icon(
                    Icons.qr_code_2,
                    color: p.readyForBuyers ? Brand.primary : Brand.muted,
                  ),
                  title: 'Share and preview',
                  subtitle: p.readyForBuyers
                      ? 'Link, QR code and the page buyers will see'
                      : 'Not ready yet. Needs ${p.missingForBuyers.join(' and ')}.',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (p.readyForBuyers) {
                      showShareSheet(context, p);
                    } else {
                      showMsg(
                        context,
                        'Add ${p.missingForBuyers.join(' and ')} first. Tap Edit.',
                        error: true,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Stock history',
            child: history.isEmpty
                ? const Text(
                    'No stock movements yet.',
                    style: TextStyle(color: Brand.muted),
                  )
                : Column(
                    children: [
                      for (final m in history.take(40))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(m.type.label),
                          subtitle: Text(
                            '${dateTimeFmt(m.at)}${m.note.isEmpty ? '' : '\n${m.note}'}',
                          ),
                          isThreeLine: m.note.isNotEmpty,
                          trailing: Text(
                            '${m.delta > 0 ? '+' : ''}${m.delta}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: m.delta >= 0 ? Brand.good : Brand.bad,
                            ),
                          ),
                        ),
                      if (history.length > 40)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Showing the latest 40 of ${history.length}',
                            style: const TextStyle(
                              color: Brand.muted,
                              fontSize: 12,
                            ),
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

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Fact(this.label, this.value, {this.color = Brand.navy});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Brand.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: Brand.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for stock in / out / damaged / recount.
Future<void> showStockSheet(
  BuildContext context,
  Product p,
  MoveType type,
) async {
  final qty = TextEditingController(
    text: type == MoveType.adjust ? p.stock.toString() : '',
  );
  final note = TextEditingController();
  final store = context.store;
  String? error;

  final title = switch (type) {
    MoveType.stockIn => 'Stock in',
    MoveType.stockOut => 'Stock out',
    MoveType.damaged => 'Damaged / lost',
    _ => 'Count stock',
  };
  final hint = switch (type) {
    MoveType.stockIn => 'How many did you receive?',
    MoveType.stockOut => 'How many are leaving (not a sale)?',
    MoveType.damaged => 'How many were damaged or lost? Their cost counts as a loss in your profit.',
    _ => 'Enter the real number on your shelf. Stock will be corrected to it.',
  };

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title · ${p.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(hint, style: const TextStyle(color: Brand.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: type == MoveType.adjust
                      ? 'Counted quantity'
                      : 'Quantity',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final n = int.tryParse(qty.text.trim());
                  if (n == null) {
                    setSheet(() => error = 'Enter a whole number');
                    return;
                  }
                  final res = store.adjustStock(
                    p,
                    type,
                    n,
                    note: note.text.trim(),
                  );
                  if (!res.ok) {
                    setSheet(() => error = res.error);
                    return;
                  }
                  Navigator.pop(ctx);
                  showMsg(context, 'Stock updated');
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  qty.dispose();
  note.dispose();
}
