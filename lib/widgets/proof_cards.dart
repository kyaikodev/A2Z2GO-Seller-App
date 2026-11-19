import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/link_import.dart' show usefulCaption;
import '../data/models.dart';
import 'common.dart';
import 'social.dart';

/// A buyer (and the seller's card) shows this many comments before "See all".
const commentPeek = 3;

/// One comment as a soft chat bubble. [onRemove] adds a remove button (seller).
class CommentBubble extends StatelessWidget {
  final SharedComment comment;
  final VoidCallback? onRemove;
  const CommentBubble(this.comment, {super.key, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommentAvatar(comment.author),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
              decoration: BoxDecoration(
                color: Brand.background,
                borderRadius: BorderRadius.circular(Rd.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (comment.demo) ...[
                        const SizedBox(width: 6),
                        const StatusChip('Sample', Brand.warn),
                      ],
                      const Spacer(),
                      if (onRemove != null)
                        InkResponse(
                          onTap: onRemove,
                          radius: 18,
                          child: const Tooltip(
                            message: 'Remove this comment',
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Brand.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      comment.text,
                      style: const TextStyle(height: 1.4, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "See all N comments": the full list in a sheet that scrolls by itself.
Future<void> showCommentsSheet(
  BuildContext context, {
  required SocialPlatform platform,
  required List<SharedComment> comments,
  void Function(SharedComment)? onRemove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CommentsSheet(
      platform: platform,
      comments: comments,
      onRemove: onRemove,
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  final SocialPlatform platform;
  final List<SharedComment> comments;
  final void Function(SharedComment)? onRemove;
  const _CommentsSheet({
    required this.platform,
    required this.comments,
    this.onRemove,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  @override
  Widget build(BuildContext context) {
    final list = widget.comments;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  PlatformBadge(widget.platform),
                  const SizedBox(width: 10),
                  Text(
                    '${list.length} comment${list.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Brand.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                itemCount: list.length,
                itemBuilder: (_, i) => CommentBubble(
                  list[i],
                  onRemove: widget.onRemove == null
                      ? null
                      : () {
                          widget.onRemove!(list[i]);
                          setState(() {});
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Browser-style tabs, one per social, side by side. Tap a tab or swipe the
/// content left or right to change tab, so no social is hidden below another.
/// [counts] keeps the tab order; [builder] draws the content of the chosen tab.
class SocialTabs extends StatefulWidget {
  final Map<SocialPlatform, int> counts;
  final Widget Function(SocialPlatform) builder;

  /// When true, the next tab opens by itself after [autoSwapSeconds] without
  /// the screen being touched (for buyers, who just look).
  final bool autoSwap;
  final int autoSwapSeconds;
  const SocialTabs({
    super.key,
    required this.counts,
    required this.builder,
    this.autoSwap = false,
    this.autoSwapSeconds = 6,
  });

  @override
  State<SocialTabs> createState() => _SocialTabsState();
}

class _SocialTabsState extends State<SocialTabs> {
  SocialPlatform? _picked;
  Timer? _timer;
  int _idle = 0; // whole seconds since the last touch anywhere on the screen

  @override
  void initState() {
    super.initState();
    if (widget.autoSwap) {
      // Any finger on the screen counts, not only on these tabs.
      GestureBinding.instance.pointerRouter.addGlobalRoute(_touched);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.autoSwap) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_touched);
    }
    super.dispose();
  }

  void _touched(PointerEvent e) => _idle = 0;

  void _tick() {
    if (!mounted) return;
    final keys = widget.counts.keys.toList();
    // Hold still when the screen is covered (the "See all" sheet, another
    // screen) or when the phone asks for fewer animations.
    final covered =
        ModalRoute.of(context)?.isCurrent == false ||
        !TickerMode.valuesOf(context).enabled;
    if (keys.length < 2 || covered || MediaQuery.disableAnimationsOf(context)) {
      _idle = 0;
      return;
    }
    if (++_idle < widget.autoSwapSeconds) return;
    _idle = 0;
    final sel = keys.contains(_picked) ? _picked! : keys.first;
    setState(() => _picked = keys[(keys.indexOf(sel) + 1) % keys.length]);
  }

  /// Moves to the next (+1) or previous (-1) tab; does nothing at the ends.
  void _step(List<SocialPlatform> keys, SocialPlatform sel, int delta) {
    final to = keys.indexOf(sel) + delta;
    if (to < 0 || to >= keys.length) return;
    setState(() {
      _picked = keys[to];
    });
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.counts.keys.toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    // The picked tab may be gone (its last link removed): fall back to the first.
    final sel = keys.contains(_picked) ? _picked! : keys.first;
    final still = MediaQuery.disableAnimationsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: Brand.line),
        boxShadow: Brand.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Brand.tint,
              border: Border(bottom: BorderSide(color: Brand.line)),
            ),
            // Up to four tabs share the width, so none is cut off; more than
            // that slide sideways.
            child: keys.length <= 4
                ? Row(
                    children: [
                      for (final k in keys)
                        Expanded(
                          child: _Tab(
                            platform: k,
                            count: widget.counts[k] ?? 0,
                            selected: k == sel,
                            onTap: () => setState(() => _picked = k),
                          ),
                        ),
                    ],
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final k in keys)
                          SizedBox(
                            width: 96,
                            child: _Tab(
                              platform: k,
                              count: widget.counts[k] ?? 0,
                              selected: k == sel,
                              onTap: () => setState(() => _picked = k),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -300) _step(keys, sel, 1); // swipe left: next tab
              if (v > 300) _step(keys, sel, -1); // swipe right: previous tab
            },
            // Plain and quick: the new tab fades in over a tenth of a second.
            // No sliding and no height animation, which felt dizzy.
            child: TweenAnimationBuilder<double>(
              key: ValueKey(sel),
              tween: Tween(begin: still ? 1.0 : 0.0, end: 1.0),
              duration: const Duration(milliseconds: 100),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: widget.builder(sel),
              ),
            ),
          ),
          if (keys.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final k in keys)
                      AnimatedContainer(
                        duration: Duration.zero,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == sel ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: k == sel ? platformColor(k) : Brand.line,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final SocialPlatform platform;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({
    required this.platform,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = platformColor(platform);
    return Semantics(
      button: true,
      selected: selected,
      label: '${platform.label}, $count comment${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Material(
        color: selected ? Brand.card : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      platformIcon(platform),
                      size: 20,
                      color: selected ? color : Brand.muted,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.12)
                            : Brand.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? color : Brand.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    platform.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? Brand.navy : Brand.muted,
                    ),
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

/// The content of one social's tab for a buyer: its posts, three comments,
/// then "See all".
class ProofCard extends StatelessWidget {
  final SocialPlatform platform;
  final List<SocialPost> posts;
  const ProofCard({super.key, required this.platform, required this.posts});

  @override
  Widget build(BuildContext context) {
    final all = [for (final p in posts) ...p.comments];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final post in posts) ...[
          _SourceRow(post),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, size: 28, color: Brand.muted),
                  SizedBox(height: 8),
                  Text(
                    'No comments added yet',
                    style: TextStyle(color: Brand.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  '${all.length}',
                  style: const TextStyle(color: Brand.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          for (final c in all.take(commentPeek)) CommentBubble(c),
          if (all.length > commentPeek)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => showCommentsSheet(
                  context,
                  platform: platform,
                  comments: all,
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text('See all ${all.length} comments'),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Brand.muted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shared by the seller from the public ${platform.label} post${posts.length == 1 ? '' : 's'} above.',
                  style: const TextStyle(
                    color: Brand.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The post the comments came from: picture, caption, link to the original.
class _SourceRow extends StatelessWidget {
  final SocialPost post;
  const _SourceRow(this.post);

  @override
  Widget build(BuildContext context) {
    final caption = usefulCaption(post.title);
    final color = platformColor(post.platform);
    return Material(
      color: Brand.background,
      borderRadius: BorderRadius.circular(Rd.md),
      child: InkWell(
        onTap: () => openLink(context, post.url),
        borderRadius: BorderRadius.circular(Rd.md),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Rd.sm),
                child: post.thumbUrl != null
                    ? ProductThumb(path: post.thumbUrl, size: 56)
                    : Container(
                        width: 56,
                        height: 56,
                        color: color.withValues(alpha: 0.10),
                        child: Icon(
                          platformIcon(post.platform),
                          color: color,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty) ...[
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          height: 1.35,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'View original post',
                      style: const TextStyle(
                        color: Brand.info,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: Brand.muted),
            ],
          ),
        ),
      ),
    );
  }
}
