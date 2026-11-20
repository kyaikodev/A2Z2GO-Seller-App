import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';
import 'social.dart';

/// The pieces of the A2Z2GO website's phone product page, with the sizes and
/// colors measured from the live page (a2z2go.com, 375 px wide).
class Site {
  static const yellow = Color(0xFFFCB800);
  static const priceRed = Color(0xFFFF3300);
  static const badgeOrange = Color(0xFFF14705);
  static const grey = Color(0xFF999999);
  static const panel = Color(0xFFF4F4F4);
  static const band = Color(0xFFF1F1F1);
  static const link = Color(0xFF0099CC);

  /// For small text on white: the page's blue, darkened to 5:1 contrast.
  static const linkText = Color(0xFF0077A3);

  /// Secondary text on white at 5.7:1 (the site's #999 is only 2.9:1).
  static const muted = Color(0xFF666666);
  static const line = Color(0xFFE5E5E5);
  static const border = Color(0xFFD9D9D9);
  static const inputLine = Color(0xFFCCCCCC);
  static const edge = 15.0; // the page side space
}

/// What a tap on a button that only looks the part does. In the seller's
/// preview it says so; on the shared page (see [BuyerProductScreen.share]) it
/// opens the real product on the website, so nothing is a dead end.
class PreviewTaps extends InheritedWidget {
  final void Function(BuildContext context) open;
  const PreviewTaps({super.key, required this.open, required super.child});

  /// True on the shared page, where taps leave for the website.
  static bool isShared(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreviewTaps>() != null;

  /// Runs the tap. [preview] is what the seller's preview does instead.
  static void fire(BuildContext context, {void Function()? preview}) {
    final taps = context.getInheritedWidgetOfExactType<PreviewTaps>();
    if (taps != null) {
      taps.open(context);
    } else if (preview != null) {
      preview();
    } else {
      showMsg(context, 'This is a preview. It is not connected yet.');
    }
  }

  @override
  bool updateShouldNotify(PreviewTaps old) => false;
}

void _soon(BuildContext context) => PreviewTaps.fire(context);

/// The website header: a small line, and the logo with cart and user icons.
/// (The website's search bar is left out on purpose.) Cart and user only look
/// the part until the shop is connected.
class SiteTopBar extends StatelessWidget {
  const SiteTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 13, color: Colors.black);
    Widget link(String text) => InkWell(
      onTap: () => _soon(context),
      child: Text(text, style: small),
    );
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        Site.edge,
        MediaQuery.paddingOf(context).top + 11,
        Site.edge,
        12,
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                link('Store Location'),
                const SizedBox(width: 12),
                Container(width: 1, height: 14, color: Brand.line),
                const SizedBox(width: 12),
                link('Track Order'),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Image.asset(
                'assets/brand/a2z_tag.png',
                height: 66,
                semanticLabel: 'A2Z2GO',
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _soon(context),
                tooltip: 'Cart',
                icon: const Icon(Icons.shopping_bag_outlined, size: 30),
              ),
              IconButton(
                onPressed: () => _soon(context),
                tooltip: 'Account',
                icon: const Icon(Icons.person_outline, size: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Home / Product name" on the grey band. "Home" goes back, like the link.
class BreadcrumbBar extends StatelessWidget {
  final String name;
  const BreadcrumbBar({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, color: Colors.black);
    return Container(
      width: double.infinity,
      color: Site.band,
      padding: const EdgeInsets.symmetric(horizontal: Site.edge, vertical: 9),
      child: Row(
        children: [
          InkWell(
            onTap: () => PreviewTaps.isShared(context)
                ? PreviewTaps.fire(context)
                : Navigator.maybePop(context),
            child: const Text(
              'Home',
              style: TextStyle(fontSize: 14, color: Site.link),
            ),
          ),
          const Text('  /  ', style: style),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three square share buttons under the SKU (Facebook, Twitter, Google).
class ShareButtons extends StatelessWidget {
  const ShareButtons({super.key});

  @override
  Widget build(BuildContext context) {
    Widget btn(Color color, Widget child, String label) => Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => _soon(context),
          child: Container(
            width: 40,
            height: 40,
            color: color,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
    const glyph = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    );
    return Row(
      children: [
        btn(const Color(0xFF1B4E9B), const Text('f', style: glyph), 'Facebook'),
        btn(const Color(0xFF00AEEF), const Text('t', style: glyph), 'Twitter'),
        btn(const Color(0xFFD93025), const Text('G', style: glyph), 'Google'),
      ],
    );
  }
}

/// The orange "-50%" tag in the top right corner of the photo.
class DiscountBadge extends StatelessWidget {
  final int percent;
  const DiscountBadge(this.percent, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    color: Site.badgeOrange,
    child: Text(
      '-$percent%',
      style: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}

/// "Vendor : shop", the orange price with the old price struck through, and the
/// stock line.
class PriceBlock extends StatelessWidget {
  final String shop;
  final double price;
  final double oldPrice;
  final String stockText;

  const PriceBlock({
    super.key,
    required this.shop,
    required this.price,
    required this.oldPrice,
    required this.stockText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text.rich(
            TextSpan(
              text: 'Vendor : ',
              style: const TextStyle(fontSize: 15),
              children: [TextSpan(text: shop)],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            Text(
              peso(price),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Site.priceRed,
              ),
            ),
            if (oldPrice > price)
              Text(
                peso(oldPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Site.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(stockText, style: const TextStyle(fontSize: 15)),
      ],
    );
  }
}

/// "Quantity", the minus/plus box, the yellow "Add To Cart" button and the heart.
/// Only for products in stock. It looks the part until the cart is connected.
class AddToCartRow extends StatefulWidget {
  /// Shared with the comments strip so the two never move at the same time.
  final NudgeLock? lock;
  const AddToCartRow({super.key, this.lock});

  @override
  State<AddToCartRow> createState() => _AddToCartRowState();
}

class _AddToCartRowState extends State<AddToCartRow> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, VoidCallback onTap, String label) => SizedBox(
      width: 40,
      height: 37,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, size: 14),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantity:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 0),
              Container(
                width: 100,
                height: 37,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFD9D9D9),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  children: [
                    step(
                      Icons.remove,
                      () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                      'Less',
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_qty',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    step(Icons.add, () => setState(() => _qty++), 'More'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 5),
          Expanded(
            child: SizedBox(
              height: 52,
              child: Nudge(
                kind: NudgeKind.wiggle,
                every: NudgeTiming.cartEvery,
                amount: NudgeTiming.cartWiggle,
                length: NudgeTiming.cartLength,
                lock: widget.lock,
                child: FilledButton(
                  onPressed: () => PreviewTaps.fire(
                    context,
                    preview: () => showMsg(context, 'The cart is coming soon.'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Site.yellow,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: appFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Add To Cart'),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _soon(context),
            tooltip: 'Wish list',
            icon: const Icon(Icons.favorite_border, size: 26, color: Site.grey),
          ),
        ],
      ),
    );
  }
}

/// The grey box with the four store promises (minimum order, returns, payment,
/// support).
class FeatureBox extends StatelessWidget {
  const FeatureBox({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 30, color: Site.yellow),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(text, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      color: Site.panel,
      padding: const EdgeInsets.all(Site.edge),
      child: Column(
        children: [
          item(Icons.rocket_launch_outlined, 'Minimum', 'orders of ₱350'),
          item(Icons.sync, '7 Days Return', 'If goods have problems'),
          item(
            Icons.credit_card_outlined,
            'Secure Payment',
            '100% secure payment',
          ),
          item(Icons.forum_outlined, '24/7 Support', 'Dedicated support'),
        ],
      ),
    );
  }
}

/// The page's tabs on a phone: grey bars you tap to open one at a time
/// (More Information, Reviews, More Seller).
class SiteAccordion extends StatefulWidget {
  final List<String> titles;
  final List<Widget> bodies;
  final int initiallyOpen;
  const SiteAccordion({
    super.key,
    required this.titles,
    required this.bodies,
    this.initiallyOpen = 0,
  });

  @override
  State<SiteAccordion> createState() => SiteAccordionState();
}

class SiteAccordionState extends State<SiteAccordion> {
  late int _open = widget.initiallyOpen;
  late final _headers = List.generate(widget.titles.length, (_) => GlobalKey());

  /// Where tab [i]'s bar is on screen (null while it is not built yet).
  BuildContext? headerContext(int i) => _headers[i].currentContext;

  /// Opens tab [i] and scrolls its bar into view.
  void show(int i) {
    setState(() => _open = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _headers[i].currentContext;
      if (c == null) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.titles.length; i++) ...[
          InkWell(
            key: _headers[i],
            onTap: () => setState(() => _open = _open == i ? -1 : i),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              color: Site.panel,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.titles[i],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _open == i ? Colors.black : Site.grey,
                ),
              ),
            ),
          ),
          if (_open == i)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(22),
              child: widget.bodies[i],
            ),
          const SizedBox(height: 5.5),
        ],
      ],
    );
  }
}

/// One comment shown in the glimpse strip.
class PeekComment {
  final String author;
  final String text;
  final String source; // "TikTok", "Facebook"...
  const PeekComment(this.author, this.text, this.source);
}

/// The strip above the bottom bar: one real comment (swapped for another, in
/// shuffled order, every [interval]) and a yellow "See all (N)" button like the
/// site's "Add To Cart". Tapping anywhere on it goes to the comments.
///
/// Care taken: the rotation pauses while a finger is on the strip, does not
/// run at all when the phone asks for reduced motion, and a screen reader
/// hears one clear button instead of a text that keeps changing.
class CommentsPeek extends StatefulWidget {
  final List<PeekComment> comments;
  final int count;
  final VoidCallback onTap;
  final Duration interval;

  /// Only for tests: a seeded Random makes the shuffle predictable.
  final Random? random;
  const CommentsPeek({
    super.key,
    required this.comments,
    required this.count,
    required this.onTap,
    this.interval = const Duration(seconds: 6),
    this.random,
  });

  @override
  State<CommentsPeek> createState() => _CommentsPeekState();
}

class _CommentsPeekState extends State<CommentsPeek> {
  late final Random _rng = widget.random ?? Random();
  late List<PeekComment> _order = _shuffled();
  int _at = 0;
  bool _held = false; // a finger is on the strip
  Timer? _timer;

  List<PeekComment> _shuffled() => [...widget.comments]..shuffle(_rng);

  @override
  void initState() {
    super.initState();
    if (widget.comments.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) => _next());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (!mounted || _held || MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      if (_at + 1 < _order.length) {
        _at++;
        return;
      }
      // Everyone has had a turn: shuffle again, but never repeat the last one.
      final last = _order[_at];
      _order = _shuffled();
      if (_order.length > 1 && identical(_order.first, last)) {
        _order.add(_order.removeAt(0));
      }
      _at = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_order.isEmpty) return const SizedBox.shrink();
    final c = _order[_at];
    final still = MediaQuery.disableAnimationsOf(context);
    final n = widget.count;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'See all $n comment${n == 1 ? '' : 's'}. ${c.author} says: ${c.text}',
      onTap: widget.onTap,
      child: Listener(
        onPointerDown: (_) => _held = true,
        onPointerUp: (_) => _held = false,
        onPointerCancel: (_) => _held = false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            // The same shadow as the website's fixed bottom bar.
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 3,
                offset: Offset(0, -1),
              ),
              BoxShadow(
                color: Color(0x3D000000),
                blurRadius: 2,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Site.edge,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: still
                              ? Duration.zero
                              : const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _row(c, key: ValueKey(identityHashCode(c))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _button(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(PeekComment c, {Key? key}) {
    return Row(
      key: key,
      children: [
        CommentAvatar(c.author, radius: 16, square: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: c.author,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '  ${c.source}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Site.muted,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                c.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The same yellow rectangle as the site's buttons (2 px corners, black text).
  Widget _button() {
    // No `alignment` on the Container: it would grow to fill all the height it
    // is offered (the strip once filled the whole screen). Center with a
    // heightFactor takes only the height it needs, at least 44.
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Site.yellow,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
        heightFactor: 1,
        widthFactor: 1,
        child: Text(
          'See all (${widget.count})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// How often and how much the two attention nudges move. All the numbers are
/// here, so they are easy to tune.
class NudgeTiming {
  /// The comments strip hops up this often...
  static const barEvery = Duration(seconds: 9);
  static const barHop = 6.0; // pixels
  static const barLength = Duration(milliseconds: 500);

  /// ...and the Add To Cart button wiggles this often (a different rhythm, so
  /// the two rarely meet).
  static const cartEvery = Duration(seconds: 13);
  static const cartWiggle = 3.0; // pixels, each side
  static const cartLength = Duration(milliseconds: 450);
}

/// Keeps two nudges from moving at the same moment: a nudge that finds the
/// other one busy skips that turn.
class NudgeLock {
  bool _busy = false;

  bool tryStart() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void end() => _busy = false;
}

enum NudgeKind { hop, wiggle }

/// A small, regular movement that draws the eye to something: a hop up or a
/// side-to-side wiggle, every [every]. It only shifts the picture (the layout
/// never moves), pauses while a finger is on it, and does nothing when the
/// phone asks for reduced motion.
class Nudge extends StatefulWidget {
  final Widget child;
  final NudgeKind kind;
  final Duration every;
  final double amount;
  final Duration length;
  final NudgeLock? lock;
  const Nudge({
    super.key,
    required this.child,
    required this.kind,
    required this.every,
    required this.amount,
    required this.length,
    this.lock,
  });

  @override
  State<Nudge> createState() => _NudgeState();
}

class _NudgeState extends State<Nudge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.length,
  );
  Timer? _timer;
  bool _held = false; // a finger is on it

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _c.value = 0;
        widget.lock?.end();
      }
    });
    _timer = Timer.periodic(widget.every, (_) => _fire());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_c.isAnimating) widget.lock?.end();
    _c.dispose();
    super.dispose();
  }

  void _fire() {
    if (!mounted || _held || _c.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (widget.lock != null && !widget.lock!.tryStart()) return;
    _c.forward(from: 0);
  }

  Offset _offset(double t) => switch (widget.kind) {
    // One arc up and back down.
    NudgeKind.hop => Offset(0, -widget.amount * sin(pi * t)),
    // Two quick swings that fade out.
    NudgeKind.wiggle => Offset(widget.amount * sin(4 * pi * t) * (1 - t), 0),
  };

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _held = true,
      onPointerUp: (_) => _held = false,
      onPointerCancel: (_) => _held = false,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) =>
            Transform.translate(offset: _offset(_c.value), child: child),
      ),
    );
  }
}
