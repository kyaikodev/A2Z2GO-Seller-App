import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// A product the way the A2Z2GO website shows it: square photo, name, and an
/// orange price, inside a thin box.
class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final cover = p.imagePath;
    Widget placeholder() => Container(
      color: Brand.tint,
      alignment: Alignment.center,
      child: Icon(categoryIcon(p.category), size: 36, color: Brand.muted),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.md),
        side: const BorderSide(color: Brand.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: cover == null
                  ? placeholder()
                  : LayoutBuilder(
                      builder: (_, box) => photoImage(
                        cover,
                        width: box.maxWidth,
                        height: box.maxWidth,
                        placeholder: placeholder,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peso(p.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Brand.price,
                    ),
                  ),
                  if (p.isOut)
                    const Text(
                      'Out of stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Brand.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Products in two columns (website phone layout). Rows grow with the text, so
/// large fonts never overflow.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onOpen;
  const ProductGrid({super.key, required this.products, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    ProductTile tile(Product p) =>
        ProductTile(product: p, onTap: () => onOpen(p));
    return Column(
      children: [
        for (var i = 0; i < products.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(products[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < products.length
                      ? tile(products[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
