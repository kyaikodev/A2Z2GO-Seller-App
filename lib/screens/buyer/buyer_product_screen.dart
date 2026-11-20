import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/product_page.dart';
import '../../widgets/proof_cards.dart';
import '../../widgets/scope.dart';
import '../../widgets/social.dart';

/// What a buyer sees after opening the seller's share link: the A2Z2GO website's
/// phone product page, with the social posts and comments (proof that the
/// product is real) where the website has its "Reviews" tab.
/// The cart, share, search and menu buttons look the part but are not connected.
class BuyerProductScreen extends StatefulWidget {
  final String productId;

  /// Only for tests: makes the shuffle of the comment strip predictable.
  final Random? random;
  const BuyerProductScreen({super.key, required this.productId, this.random});

  @override
  State<BuyerProductScreen> createState() => _BuyerProductScreenState();
}

class _BuyerProductScreenState extends State<BuyerProductScreen> {
  @override
  void initState() {
    super.initState();
    // A quick note, not a banner that stays in the way.
    _scroll.addListener(_checkPeek);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMsg(context, 'This is how buyers will see your product.');
      _checkPeek();
    });
  }

  final _pageCtrl = PageController();
  final _tabs = GlobalKey<SiteAccordionState>();

  /// The comments strip and the Add To Cart button take turns nudging.
  final _nudges = NudgeLock();
  final _scroll = ScrollController();
  int _page = 0;

  /// The peek strip shows until the buyer has scrolled down to the comments.
  bool _peek = true;

  void _checkPeek() {
    final c = _tabs.currentState?.headerContext(1);
    var show = true;
    if (c != null && c.mounted) {
      final box = c.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final top = box.localToGlobal(Offset.zero).dy;
        show = top > MediaQuery.sizeOf(context).height - 80;
      }
    }
    if (show != _peek) setState(() => _peek = show);
  }

  @override
  void dispose() {
    _scroll.dispose();
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
    const edge = EdgeInsets.symmetric(horizontal: Site.edge);

    return Scaffold(
      backgroundColor: Colors.white,
      // Only the comments strip is stuck to the bottom. The page is a preview of
      // what the buyer sees; anything a buyer taps goes to the website.
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomCenter,
        child: _peek && p.commentCount > 0
            ? _peekStrip(p)
            : const SizedBox(width: double.infinity),
      ),
      // A scroll view with a column, not a lazy list: every part is built, so
      // the comments tab can always be found and scrolled to.
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SiteTopBar(),
            BreadcrumbBar(name: p.name),
            Padding(
              padding: const EdgeInsets.fromLTRB(Site.edge, 20, Site.edge, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      text: 'SKU:',
                      style: const TextStyle(fontSize: 15),
                      children: [
                        TextSpan(
                          text: '  ${p.sku}',
                          style: const TextStyle(color: Site.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const ShareButtons(),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE5E5E5)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(padding: edge, child: _gallery(p)),
            Padding(
              padding: const EdgeInsets.fromLTRB(Site.edge, 0, Site.edge, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PriceBlock(
                    shop: shop,
                    price: p.price,
                    oldPrice: p.oldPrice,
                    stockText: soldOut
                        ? 'Out of stock'
                        : p.isLow
                        ? 'Only ${p.stock} left'
                        : 'In stock',
                  ),
                  if (!soldOut) AddToCartRow(lock: _nudges),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(Site.edge, 10, Site.edge, 20),
              child: FeatureBox(),
            ),
            SiteAccordion(
              key: _tabs,
              initiallyOpen: p.posts.isNotEmpty ? 1 : 0,
              titles: const [
                'More Information',
                'What people are saying',
                'More Seller',
              ],
              bodies: [_info(p), _proof(p), _moreSeller()],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// The glimpse above the bottom bar: the count and the first real comment.
  Widget _peekStrip(Product p) {
    return Nudge(
      kind: NudgeKind.hop,
      every: NudgeTiming.barEvery,
      amount: NudgeTiming.barHop,
      length: NudgeTiming.barLength,
      lock: _nudges,
      child: _strip(p),
    );
  }

  Widget _strip(Product p) {
    return CommentsPeek(
      comments: [
        for (final post in p.posts)
          for (final c in post.comments)
            if (c.text.trim().isNotEmpty)
              PeekComment(c.author, c.text.trim(), post.platform.label),
      ],
      count: p.commentCount,
      random: widget.random,
      onTap: () => _tabs.currentState?.show(1),
    );
  }

  /// The photo, square like the website's, with the discount tag on top.
  Widget _gallery(Product p) {
    Widget placeholder() => Container(
      color: Brand.tint,
      child: Center(
        child: Icon(categoryIcon(p.category), size: 64, color: Brand.muted),
      ),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: p.images.isEmpty
                ? placeholder()
                : PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final img in p.images)
                        photoImage(
                          img,
                          fit: BoxFit.contain,
                          placeholder: placeholder,
                        ),
                    ],
                  ),
          ),
          if (p.discountPercent > 0)
            Positioned(
              top: 0,
              right: 0,
              child: DiscountBadge(p.discountPercent),
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

  /// "More Information": the details and the description.
  Widget _info(Product p) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.brand.isNotEmpty) row('Brand', p.brand),
        row('Category', p.category),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          ExpandableText(p.description, style: const TextStyle(height: 1.45)),
        ],
        if (p.sourceUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => openLink(context, p.sourceUrl),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 15, color: Brand.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Listed at ${Uri.tryParse(p.sourceUrl)?.host ?? p.sourceUrl}',
                    style: const TextStyle(color: Brand.info, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Where the website has "Reviews": the real posts and comments.
  Widget _proof(Product p) {
    if (p.posts.isEmpty) {
      return const Text(
        'No comments added yet.',
        style: TextStyle(fontSize: 15, color: Brand.muted),
      );
    }
    final groups = groupByPlatform(p.posts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialTabs(
          flat: true,
          autoSwap: true,
          counts: {
            for (final g in groups.entries)
              g.key: g.value.fold(0, (n, x) => n + x.comments.length),
          },
          builder: (k) => ProofCard(platform: k, posts: groups[k]!, flat: true),
        ),
      ],
    );
  }

  Widget _moreSeller() => const Text(
    'No Other Seller Selling this Product',
    style: TextStyle(fontSize: 15),
  );
}
