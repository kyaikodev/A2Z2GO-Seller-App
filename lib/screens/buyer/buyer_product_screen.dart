import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import '../../widgets/social.dart';
import '../products/proof_screen.dart' show CommentAvatar;

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
  final _pageCtrl = PageController();
  int _page = 0;
  final Set<String> _expanded = {};

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
          Container(
            width: double.infinity,
            color: Brand.accent.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'This is how buyers will see your product.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          _gallery(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peso(p.price),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Brand.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 17,
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
                        style: TextStyle(color: Brand.muted, fontSize: 12.5),
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(p.description, style: const TextStyle(height: 1.45)),
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
                                fontSize: 12.5,
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
                  Text(
                    'What people are saying',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Posts and public comments about this product. Each one links to its original so you can check it.',
                    style: TextStyle(color: Brand.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  for (final post in p.posts) ...[
                    _postCard(post),
                    const SizedBox(height: 12),
                  ],
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

  Widget _postCard(SocialPost post) {
    final open = _expanded.contains(post.id);
    final shown = open ? post.comments : post.comments.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlatformBadge(post.platform),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  onTap: () => openLink(context, post.url),
                  borderRadius: BorderRadius.circular(Rd.sm),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'View original',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Brand.info, fontSize: 12.5),
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.open_in_new, size: 14, color: Brand.info),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (post.thumbUrl != null || post.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.thumbUrl != null) ...[
                  ProductThumb(path: post.thumbUrl, size: 64),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          ],
          if (post.comments.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              '${post.comments.length} comment${post.comments.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final c in shown)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommentAvatar(c.author),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                c.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (c.demo)
                                const StatusChip('Sample', Brand.warn),
                            ],
                          ),
                          Text(c.text, style: const TextStyle(height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (post.comments.length > 3)
              TextButton(
                onPressed: () => setState(() {
                  open ? _expanded.remove(post.id) : _expanded.add(post.id);
                }),
                child: Text(
                  open
                      ? 'Show fewer'
                      : 'Show all ${post.comments.length} comments',
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Shared by the seller from the public ${post.platform.label} post above.',
              style: const TextStyle(color: Brand.muted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
