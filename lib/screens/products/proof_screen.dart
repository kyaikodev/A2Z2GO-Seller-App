import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/link_import.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/proof_cards.dart';
import '../../widgets/scope.dart';
import '../../widgets/social.dart';
import 'import_comments_screen.dart';

/// The seller's list of linked posts and the comments copied from them.
class ProofScreen extends StatelessWidget {
  final String productId;
  const ProofScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final p = context.store.productById(productId);
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
    final store = context.store;
    void changed() => store.updateProduct(p);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social proof'),
        actions: [
          IconButton(
            tooltip: 'Add a link',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showPostSheet(context, p.posts, changed),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [SocialProofSection(posts: p.posts, onChanged: changed)],
      ),
    );
  }
}

/// The list of linked posts with their comments, and the button to add more.
/// Works on any list of posts, so the product page and the Add/Edit form share
/// it. [onChanged] runs after every change (save, or rebuild the form).
class SocialProofSection extends StatelessWidget {
  final List<SocialPost> posts;
  final VoidCallback onChanged;
  const SocialProofSection({
    super.key,
    required this.posts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Brand.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: Brand.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buyers see these posts and comments on your product page, '
                  'with a link to the original so they can check it themselves. '
                  'Only add public comments, and always keep the link to where they came from.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (posts.isNotEmpty) ...[
          Builder(
            builder: (_) {
              final groups = groupByPlatform(posts);
              return SocialTabs(
                counts: {
                  for (final g in groups.entries)
                    g.key: g.value.fold(0, (n, x) => n + x.comments.length),
                },
                builder: (k) => Column(
                  children: [
                    for (final post in groups[k]!) ...[
                      _PostCard(posts: posts, post: post, onChanged: onChanged),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => showPostSheet(context, posts, onChanged),
          icon: const Icon(Icons.add_link),
          label: Text(
            posts.isEmpty
                ? 'Add a Facebook, Instagram or TikTok link'
                : 'Add another link',
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final List<SocialPost> posts;
  final SocialPost post;
  final VoidCallback onChanged;
  const _PostCard({
    required this.posts,
    required this.post,
    required this.onChanged,
  });

  void _remove(BuildContext context, SharedComment c) {
    final at = post.comments.indexWhere((e) => e.id == c.id);
    if (at < 0) return;
    post.comments.removeAt(at);
    onChanged();
    showMsg(
      context,
      'Comment removed',
      actionLabel: 'Undo',
      onAction: () {
        post.comments.insert(at.clamp(0, post.comments.length), c);
        onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.md),
        side: const BorderSide(color: Brand.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // the platform is in the section heading above, so show the site
                Expanded(
                  child: Text(
                    Uri.tryParse(post.url)?.host ?? post.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.muted, fontSize: 13),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showPostSheet(context, posts, onChanged, post: post);
                    } else {
                      final ok = await confirmDialog(
                        context,
                        title: 'Remove this link?',
                        message:
                            'The link and its ${post.comments.length} comment${post.comments.length == 1 ? '' : 's'} are removed from this product.',
                        confirmLabel: 'Remove',
                        destructive: true,
                      );
                      if (ok) {
                        posts.removeWhere((e) => e.id == post.id);
                        onChanged();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit link')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            if (post.thumbUrl != null || usefulCaption(post.title).isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.thumbUrl != null) ...[
                    ProductThumb(path: post.thumbUrl, size: 64),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      usefulCaption(post.title).isEmpty
                          ? 'Post'
                          : usefulCaption(post.title),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => openLink(context, post.url),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 15, color: Brand.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.info, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Text(
              post.comments.isEmpty
                  ? 'No comments added yet'
                  : '${post.comments.length} comment${post.comments.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final c in post.comments.take(commentPeek))
              CommentBubble(c, onRemove: () => _remove(context, c)),
            if (post.comments.length > commentPeek)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showCommentsSheet(
                    context,
                    platform: post.platform,
                    comments: post.comments,
                    onRemove: (c) {
                      post.comments.removeWhere((e) => e.id == c.id);
                      onChanged();
                    },
                  ),
                  child: Text('See all ${post.comments.length} comments'),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ImportCommentsScreen(post: post, onChanged: onChanged),
                ),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Add comments'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- add a link

Future<void> showPostSheet(
  BuildContext context,
  List<SocialPost> posts,
  VoidCallback onChanged, {
  SocialPost? post,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PostSheet(
      posts: posts,
      onChanged: onChanged,
      post: post,
      launchContext: context,
    ),
  );
}

class _PostSheet extends StatefulWidget {
  final List<SocialPost> posts;
  final VoidCallback onChanged;
  final SocialPost? post;

  /// The screen under the sheet. After a NEW link is saved we open the
  /// "add comments" screen from here, so the seller goes straight on.
  final BuildContext launchContext;
  const _PostSheet({
    required this.posts,
    required this.onChanged,
    this.post,
    required this.launchContext,
  });

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  late final _url = TextEditingController(text: widget.post?.url ?? '');
  late final _title = TextEditingController(text: widget.post?.title ?? '');
  late String? _thumb = widget.post?.thumbUrl;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  SocialPlatform get _platform => SocialPlatformX.fromUrl(_url.text);

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await fetchLinkInfo(_url.text);
      if (!mounted) return;
      setState(() {
        final caption = (info.description ?? '').trim();
        // Social pages put the caption in the description; the title is just
        // the page or brand name.
        final best = _platform != SocialPlatform.link && caption.isNotEmpty
            ? caption
            : (info.title ?? caption);
        if (_title.text.trim().isEmpty) _title.text = best;
        _thumb = info.image ?? _thumb;
      });
    } on LinkImportException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(() => _error = 'Paste the full link starting with https://');
      return;
    }
    final existing = widget.post;
    SocialPost? created;
    if (existing == null) {
      created = SocialPost(
        id: newId('s'),
        platform: _platform,
        url: url,
        title: _title.text.trim(),
        thumbUrl: _thumb,
      );
      widget.posts.add(created);
    } else {
      existing
        ..platform = _platform
        ..url = url
        ..title = _title.text.trim()
        ..thumbUrl = _thumb;
    }
    widget.onChanged();
    final launch = widget.launchContext;
    Navigator.pop(context);
    if (created != null && launch.mounted) {
      final post = created;
      Navigator.push(
        launch,
        MaterialPageRoute(
          builder: (_) =>
              ImportCommentsScreen(post: post, onChanged: widget.onChanged),
        ),
      );
    } else if (launch.mounted) {
      showMsg(launch, 'Link updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post == null ? 'Add a link' : 'Edit link',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'A public Facebook, Instagram, TikTok or YouTube post, or any page that talks about this product.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Post link',
                hintText: 'https://www.facebook.com/…',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PlatformBadge(_platform),
                const Spacer(),
                TextButton.icon(
                  onPressed: _busy ? null : _preview,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Get preview'),
                ),
              ],
            ),
            if (_thumb != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProductThumb(path: _thumb, size: 72),
              ),
            TextField(
              controller: _title,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Caption (shown to buyers)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(widget.post == null ? 'Next' : 'Save link'),
            ),
          ],
        ),
      ),
    );
  }
}
