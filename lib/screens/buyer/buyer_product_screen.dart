import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/proof_cards.dart';
import '../../widgets/scope.dart';
import '../../widgets/social.dart';

/// What a buyer sees after opening the seller's share link: the photos, the
/// details, and the social posts and comments that show the product is real.
/// The cart button is a placeholder for now.
class BuyerProductScreen extends StatefulWidget {
  final String productId;
  const BuyerProductScreen({super.key, required this.productId});

  @override
  State<BuyerProductScreen> createState() => _BuyerProductScreenState();
}

class _BuyerProductScreenState extends State<BuyerProductScreen> {
  @override
  void initState() {
    super.initState();
    // A quick note, not a banner that stays in the way.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMsg(context, 'This is how buyers will see your product.');
    });
  }

  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final p = store.productById(widget.productId);
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
    final shop = store.account.storeName;
    final soldOut = p.isOut;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Buyer preview')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Brand.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  // Placeholder: the cart is not connected yet.
                  onPressed: soldOut
                      ? null
                      : () => showMsg(context, 'The cart is coming soon.'),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(soldOut ? 'Sold out' : 'Add to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _gallery(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peso(p.price),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Brand.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (p.brand.isNotEmpty) StatusChip(p.brand, Brand.info),
                    StatusChip(p.category, Brand.muted),
                    soldOut
                        ? const StatusChip('Sold out', Brand.bad)
                        : p.isLow
                        ? StatusChip('Only ${p.stock} left', Brand.warn)
                        : const StatusChip('In stock', Brand.good),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CommentAvatar(shop, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Seller',
                        style: TextStyle(color: Brand.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.description.isNotEmpty) ...[
            const Divider(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About this product',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  ExpandableText(
                    p.description,
                    style: const TextStyle(height: 1.45),
                  ),
                  if (p.sourceUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => openLink(context, p.sourceUrl),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.open_in_new,
                            size: 15,
                            color: Brand.info,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Listed at ${Uri.tryParse(p.sourceUrl)?.host ?? p.sourceUrl}',
                              style: const TextStyle(
                                color: Brand.info,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (p.posts.isNotEmpty) ...[
            const Divider(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What people are saying',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Public posts and comments about this product. Open the original to check each one. Swipe to change social.',
                    style: TextStyle(color: Brand.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (_) {
                      final groups = groupByPlatform(p.posts);
                      return SocialTabs(
                        autoSwap: true,
                        counts: {
                          for (final g in groups.entries)
                            g.key: g.value.fold(
                              0,
                              (n, x) => n + x.comments.length,
                            ),
                        },
                        builder: (k) =>
                            ProofCard(platform: k, posts: groups[k]!),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _gallery(Product p) {
    Widget placeholder() => Container(
      color: Brand.tint,
      child: Center(
        child: Icon(categoryIcon(p.category), size: 64, color: Brand.muted),
      ),
    );
    if (p.images.isEmpty) return SizedBox(height: 300, child: placeholder());
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final img in p.images)
                photoImage(img, fit: BoxFit.contain, placeholder: placeholder),
            ],
          ),
          if (p.images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < p.images.length; i++)
                    Container(
                      width: i == _page ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _page ? Brand.primary : Brand.line,
                        borderRadius: BorderRadius.circular(4),
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
