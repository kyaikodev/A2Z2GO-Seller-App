import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

enum _Filter { all, low, out, hidden }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ProductFormScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final q = _search.text.trim().toLowerCase();

    var list =
        store.products.where((p) {
          if (q.isNotEmpty &&
              !p.name.toLowerCase().contains(q) &&
              !p.sku.toLowerCase().contains(q)) {
            return false;
          }
          if (_category != null && p.category != _category) return false;
          return switch (_filter) {
            _Filter.all => p.active,
            _Filter.low => p.active && p.isLow,
            _Filter.out => p.active && p.isOut,
            _Filter.hidden => !p.active,
          };
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final cats = store.categories;
    if (_category != null && !cats.contains(_category)) _category = null;

    return DefaultTabController(
      length: _Filter.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Products'),
          actions: [
            IconButton(
              tooltip: 'Add product',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _add,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => _filter = _Filter.values[i]),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Low stock'),
              Tab(text: 'Sold out'),
              Tab(text: 'Hidden'),
            ],
          ),
        ),
        body: store.products.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                message: 'Add what you sell, with a photo, price and cost. Orders, stock and profit are tracked from there.',
                actionLabel: 'Add your first product',
                onAction: _add,
              )
            : Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search name or SKU',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                  if (cats.length > 1)
                    Container(
                      height: 46,
                      color: Colors.white,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          Pill(
                            'Any category',
                            _category == null,
                            () => setState(() => _category = null),
                          ),
                          for (final c in cats)
                            Pill(
                              c,
                              _category == c,
                              () => setState(() => _category = c),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: list.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off,
                            title: 'Nothing matches',
                            message: 'Try a different search or filter.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => FadeSlideIn(
                              index: i,
                              animate: i < 6,
                              child: _ProductCard(product: list[i]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.md),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: p.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductThumb(path: p.imagePath, size: 72, category: p.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.sku} · ${p.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peso(p.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Brand.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!p.active)
                          const StatusChip('Hidden', Brand.muted)
                        else if (p.isOut)
                          const StatusChip('Out of stock', Brand.bad)
                        else if (p.isLow)
                          StatusChip('${p.stock} left', Brand.warn)
                        else
                          StatusChip('${p.stock} in stock', Brand.good),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
