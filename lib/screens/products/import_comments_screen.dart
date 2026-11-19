import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/comment_tools.dart';
import '../../data/link_import.dart'
    show
        desktopAgentLike,
        desktopBrowserAgent,
        mobileBrowserAgent,
        resolveShortLink;
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/pick_field.dart' show reqLabel;
import '../../widgets/social.dart';
import 'grab_script.dart';

enum _Mode { reading, showPage, failed, ready }

/// Gets the comments of a post for the seller. The post is loaded in a hidden
/// page, the app reads the comments by itself, and the seller ticks the ones
/// to keep. If the site asks for a login, the page is shown once so the seller
/// can log in. A paste box is kept as a backup.
class ImportCommentsScreen extends StatefulWidget {
  final SocialPost post;
  final VoidCallback onChanged;
  const ImportCommentsScreen({
    super.key,
    required this.post,
    required this.onChanged,
  });

  @override
  State<ImportCommentsScreen> createState() => _ImportCommentsScreenState();
}

class _ImportCommentsScreenState extends State<ImportCommentsScreen> {
  WebViewController? _web;
  _Mode _mode = _Mode.reading;
  String _message = '';
  String _details = '';
  bool _positiveFirst = false;
  List<ParsedComment> _found = [];
  final Set<int> _picked = {};
  bool _onlyPositive = false;
  bool _fromText = false;
  bool _offline = false;
  String? _startedFor; // the page address the reader was last started on
  Timer? _timeout;
  Timer? _startTimer;

  String get _fallback => '${widget.post.platform.label} user';

  /// YouTube and TikTok only show their comments on the computer layout; the
  /// phone layout hides them behind "Open app".
  bool get _needsDesktopView =>
      widget.post.platform == SocialPlatform.youtube ||
      widget.post.platform == SocialPlatform.instagram ||
      widget.post.platform == SocialPlatform.tiktok;

  /// The sites the reader knows how to read. Anything else (Shopee, Lazada, any
  /// other link) is added by hand, instead of guessing from the page text.
  bool get _supported => const {
    SocialPlatform.facebook,
    SocialPlatform.tiktok,
    SocialPlatform.instagram,
    SocialPlatform.youtube,
  }.contains(widget.post.platform);

  @override
  void initState() {
    super.initState();
    _web = _supported ? _makeController() : null;
    if (_web == null) {
      _mode = _Mode.failed;
      _message = _supported
          ? 'Reading comments needs the phone app. You can add them yourself instead.'
          : "We can't read comments from this site yet. Add them yourself instead.";
    } else {
      // Start on its own even if the page is slow to say it has loaded.
      _startTimer = Timer(const Duration(seconds: 8), _maybeStart);
      _resolveAndLoad();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _startTimer?.cancel();
    super.dispose();
  }

  WebViewController? _makeController() {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return null;
    }
    try {
      final controller = WebViewController();
      // The phone web view lays pages out narrow by default. TikTok and YouTube
      // then hide their comments, so ask for a wide, computer-sized page.
      final platform = controller.platform;
      if (_needsDesktopView && platform is AndroidWebViewController) {
        platform.setUseWideViewPort(true);
      }
      return controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          _needsDesktopView ? desktopBrowserAgent : mobileBrowserAgent,
        )
        ..addJavaScriptChannel('A2ZGrab', onMessageReceived: _onGrabbed)
        ..setNavigationDelegate(
          NavigationDelegate(
            // Start reading as soon as the page is mostly there. The script
            // itself waits only until comments show up, so there is no need to
            // wait for ads and videos to finish.
            onPageStarted: (_) => _forceWideLayout(),
            onProgress: (p) {
              _forceWideLayout();
              if (p >= 55) _maybeStart();
            },
            onPageFinished: (_) {
              _forceWideLayout();
              _maybeStart();
            },
            onWebResourceError: (error) {
              final d = error.description.toUpperCase();
              final noNet =
                  d.contains('INTERNET_DISCONNECTED') ||
                  d.contains('NAME_NOT_RESOLVED') ||
                  d.contains('NETWORK_CHANGED') ||
                  d.contains('CONNECTION_FAILED') ||
                  d.contains('NOT CONNECTED') ||
                  d.contains('OFFLINE');
              if (noNet && (error.isForMainFrame ?? true)) {
                _fail(
                  "You are offline. Check your internet, then try again.",
                  offline: true,
                );
              }
            },
            // Sites redirect to app links such as fb:// or intent://. This
            // page can't open those, so stay on the web page.
            onNavigationRequest: (request) {
              final scheme = Uri.tryParse(request.url)?.scheme ?? '';
              return (scheme == 'http' || scheme == 'https')
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        );
    } catch (_) {
      return null;
    }
  }

  /// TikTok's page ignores the phone's wide-page setting and lays out narrow
  /// (no comments panel). Tell the page it is 1280 px wide, as a computer
  /// would; the web view then shrinks it to fit the screen.
  void _forceWideLayout() {
    if (!_needsDesktopView) return;
    _web?.runJavaScript(
      "(function(){var v=document.querySelector('meta[name=viewport]');"
      "if(!v){v=document.createElement('meta');v.name='viewport';"
      "(document.head||document.documentElement).appendChild(v);}"
      "if(v.content!=='width=1280'){v.content='width=1280';"
      "window.dispatchEvent(new Event('resize'));}})();",
    );
  }

  // ---------------------------------------------------------------- reading

  /// [details] is for whoever fixes the app: it stays behind "More details".
  void _fail(String message, {bool offline = false, String details = ''}) {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() {
      _mode = _Mode.failed;
      _message = message;
      _details = details.trim();
      _offline = offline;
    });
  }

  /// Opens the post. A short share link (vt.tiktok.com/...) is first followed to
  /// the real page, and the post keeps the real address from then on.
  Future<void> _resolveAndLoad() async {
    final web = _web;
    if (web == null) return;
    final real = await resolveShortLink(widget.post.url);
    if (!mounted) return;
    if (real != widget.post.url) {
      widget.post.url = real;
      widget.onChanged();
    }
    if (_needsDesktopView) {
      try {
        await web.setUserAgent(desktopAgentLike(await web.getUserAgent()));
      } catch (_) {}
    }
    await web.loadRequest(
      Uri.parse(widget.post.url),
      // The web view names this app in every request; leave that out.
      headers: _needsDesktopView ? const {'X-Requested-With': ''} : const {},
    );
  }

  /// Starts the reader on the page that is open now. A redirect or a new page
  /// destroys a running reader, so it is started again whenever the address
  /// changes, until comments arrive.
  Future<void> _maybeStart() async {
    final web = _web;
    if (web == null || !mounted || _mode != _Mode.reading) return;
    final full = await web.currentUrl();
    if (!mounted || _mode != _Mode.reading || full == null) return;
    // Sites tweak the query part while a page is open; that is not a new page.
    final u = Uri.tryParse(full);
    final url = u == null ? full : '${u.host}${u.path}';
    if (_startedFor == url) return;
    _startedFor = url;
    _grab();
  }

  Future<void> _grab() async {
    final web = _web;
    if (web == null || !mounted) return;
    setState(() => _mode = _Mode.reading);
    _quickTried = false;
    _arm(_needsDesktopView ? 60 : 100);
    try {
      await web.runJavaScript(grabScript);
    } catch (_) {
      _fail(
        "We couldn't open this page. Try again, or add the comments yourself.",
      );
    }
  }

  bool _quickTried = false;

  void _arm(int seconds) {
    _timeout?.cancel();
    _timeout = Timer(Duration(seconds: seconds), _onTimeout);
  }

  /// Out of time. Before giving up, ask the page once for whatever comments
  /// are already on it (the owner wants "as much as the app can").
  Future<void> _onTimeout() async {
    final web = _web;
    if (web == null || !mounted || _mode != _Mode.reading) return;
    if (!_quickTried) {
      _quickTried = true;
      _arm(20);
      try {
        await web.runJavaScript('window.__a2zQuick = true;');
        await web.runJavaScript(grabScript);
      } catch (_) {}
      return;
    }
    final facts = await _pageFacts();
    if (mounted && _mode == _Mode.reading) {
      _fail(
        'This is taking too long. Try again, or add the comments yourself.',
        details: facts,
      );
    }
  }

  Future<void> _tryAgain() async {
    final web = _web;
    if (web == null) return;
    setState(() {
      _mode = _Mode.reading;
      _startedFor = null;
      _offline = false;
    });
    await web.loadRequest(Uri.parse(widget.post.url));
  }

  void _onGrabbed(JavaScriptMessage message) {
    if (!mounted || _mode != _Mode.reading) return;
    _timeout?.cancel();
    // The page can send anything through this channel; refuse absurd sizes.
    if (message.message.length > 400000) {
      _fail('This page is too big to read. Add the comments yourself instead.');
      return;
    }
    // Always try to read, even if a login or sign-up box is on the page.
    final result = readGrabbed(message.message, _fallback);
    if (result.comments.isNotEmpty) {
      _show(result.comments, fromText: result.fromPageText);
    } else {
      _fail(
        "We couldn't find any comments on this post. They may be turned off, or hidden until you log in.",
        details: _report(message.message),
      );
    }
  }

  /// What the page looks like right now, for the "took too long" message.
  Future<String> _pageFacts() async {
    try {
      final r = await _web?.runJavaScriptReturningResult(
        "[location.hostname,innerWidth,document.querySelectorAll('ytd-comment-thread-renderer').length,"
        "document.querySelectorAll('ytd-comments').length].join(' / ')",
      );
      final facts = r.toString().replaceAll('"', '');
      return '\n(Page: host / width / YouTube comment boxes / comments section = $facts)';
    } catch (_) {
      return '';
    }
  }

  /// A short line about what the reader saw, to find out why it read nothing.
  String _report(String json) {
    try {
      final m = jsonDecode(json);
      if (m is! Map) return '';
      if (m['error'] != null) return '\n(Reader error: ${m['error']})';
      final d = m['diag'];
      if (d is! Map) return '';
      return '\n(Reader saw: ${d['boxes']} comment boxes, read ${d['read']}, '
          'YouTube boxes ${d['ytBoxes']}, with text ${d['ytWithText']}, '
          'with author ${d['ytWithAuthor']}, page width ${d['wide']})';
    } catch (_) {
      return '';
    }
  }

  void _show(
    List<ParsedComment> comments, {
    bool fromText = false,
    bool tickAll = false,
  }) {
    setState(() {
      _fromText = fromText;
      _found = comments;
      _picked
        ..clear()
        ..addAll([
          for (var i = 0; i < comments.length; i++)
            if (tickAll || comments[i].tone == CommentTone.positive) i,
        ]);
      _onlyPositive = false;
      _positiveFirst = false;
      _mode = _Mode.ready;
    });
  }

  // ------------------------------------------------------------ backup tools

  Future<void> _copyDebug() async {
    String text;
    final web = _web;
    if (web == null) {
      text = 'No in-app page here. url=${widget.post.url}';
    } else {
      try {
        final r = await web.runJavaScriptReturningResult(debugScript);
        var s = r.toString();
        if (s.startsWith('"')) {
          try {
            s = jsonDecode(s) as String;
          } catch (_) {}
        }
        text = s;
      } catch (e) {
        text = 'debug failed: $e  url=${widget.post.url}';
      }
    }
    await Clipboard.setData(ClipboardData(text: '$_details\n$text'.trim()));
    if (mounted) {
      showMsg(context, 'Copied. Send it to whoever helps you with the app.');
    }
  }

  /// The technical lines, for whoever fixes the app. Safe to share.
  Future<void> _showDetails() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('More details'),
        content: SingleChildScrollView(
          child: Text(
            'This is for whoever fixes the app. It has no passwords or personal information.\n\n'
            '${_details.isEmpty ? 'Nothing more to show.' : _details}',
            style: const TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _copyDebug();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Opens the "add comments yourself" box; what is added is ticked, because
  /// the seller typed it on purpose.
  Future<void> _addByHand() async {
    final result = await showModalBottomSheet<List<ParsedComment>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddCommentsSheet(fallbackAuthor: _fallback),
    );
    if (result != null && mounted) _show(result, tickAll: true);
  }

  // ------------------------------------------------------------------ adding

  List<int> _visible() {
    final shown = [
      for (var i = 0; i < _found.length; i++)
        if (!_onlyPositive || _found[i].tone == CommentTone.positive) i,
    ];
    if (!_positiveFirst) return shown; // as on the post
    // Positive ones first; each group keeps the order of the post.
    bool good(int i) => _found[i].tone == CommentTone.positive;
    return [...shown.where(good), ...shown.where((i) => !good(i))];
  }

  List<int> _ticked() {
    final visible = _visible().toSet();
    return _picked.where(visible.contains).toList()..sort();
  }

  void _add() {
    final existing = widget.post.comments.map((c) => c.text.trim()).toSet();
    var added = 0;
    for (final i in _ticked()) {
      final c = _found[i];
      if (existing.contains(c.text.trim())) continue;
      widget.post.comments.add(
        SharedComment(id: newId('c'), author: c.author, text: c.text),
      );
      added++;
    }
    widget.onChanged();
    Navigator.pop(context);
    showMsg(
      context,
      added == 0
          ? 'Those comments were already added.'
          : '$added comment${added == 1 ? '' : 's'} added',
    );
  }

  Color _toneColor(CommentTone t) => switch (t) {
    CommentTone.positive => Brand.good,
    CommentTone.neutral => Brand.muted,
    CommentTone.negative => Brand.bad,
    CommentTone.spam => Brand.warn,
  };

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final covered =
        _mode == _Mode.reading || _mode == _Mode.failed || _mode == _Mode.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Get comments')),
      bottomNavigationBar: _bottomBar(),
      body: Stack(
        children: [
          // The page lives here the whole time. It is hidden behind the cover
          // while reading, and shown only when the seller must log in.
          if (_web != null)
            Positioned.fill(child: WebViewWidget(controller: _web!)),
          if (covered)
            Positioned.fill(
              child: Container(color: Brand.background, child: _cover()),
            ),
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    Widget wrap(Widget child) => SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Brand.line)),
        ),
        child: child,
      ),
    );
    switch (_mode) {
      case _Mode.ready:
        final n = _ticked().length;
        return wrap(
          FilledButton(
            onPressed: n == 0 ? null : _add,
            child: Text(
              n == 0
                  ? 'Pick comments to add'
                  : 'Add $n comment${n == 1 ? '' : 's'}',
            ),
          ),
        );
      case _Mode.showPage:
        return wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scroll down until you can see the comments, then tap Read comments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _grab,
                child: const Text('Read comments'),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.failed),
                child: const Text('Back'),
              ),
            ],
          ),
        );
      case _Mode.reading:
      case _Mode.failed:
        return null;
    }
  }

  Widget _cover() {
    switch (_mode) {
      case _Mode.reading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CommentSkeletons(),
                const SizedBox(height: 28),
                const Text(
                  'Reading the comments…',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This can take up to a minute.',
                  style: TextStyle(color: Brand.muted),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      case _Mode.failed:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _offline
                      ? Icons.wifi_off_outlined
                      : Icons.comments_disabled_outlined,
                  size: 44,
                  color: Brand.muted,
                ),
                const SizedBox(height: 12),
                Text(
                  _message.isEmpty
                      ? "We couldn't get the comments. Add them yourself instead."
                      : _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (_web != null) ...[
                  FilledButton(
                    onPressed: _tryAgain,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _addByHand,
                    child: const Text('Add comments yourself'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _mode = _Mode.showPage),
                    child: const Text('See the page'),
                  ),
                ] else
                  FilledButton(
                    onPressed: _addByHand,
                    child: const Text('Add comments yourself'),
                  ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => openLink(context, widget.post.url),
                  child: Text('Open in ${widget.post.platform.label}'),
                ),
                // For whoever fixes the app: kept out of the way.
                if (_web != null)
                  TextButton(
                    onPressed: _showDetails,
                    style: TextButton.styleFrom(foregroundColor: Brand.muted),
                    child: const Text('More details'),
                  ),
              ],
            ),
          ),
        );
      case _Mode.ready:
        return _readyList();
      case _Mode.showPage:
        return const SizedBox.shrink();
    }
  }

  Widget _readyList() {
    final positive = [
      for (var i = 0; i < _found.length; i++)
        if (_found[i].tone == CommentTone.positive) i,
    ];
    final visible = _visible();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose what to keep',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Found ${_found.length}. ${positive.length} look positive. Positive ones are picked automatically, so review before adding.',
                  style: const TextStyle(color: Brand.muted, fontSize: 13),
                ),
                if (widget.post.platform == SocialPlatform.instagram)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Brand.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Instagram only shows its newest comments, and they change every few seconds. This is what was there just now, so it may not match the post a minute later.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                if (_fromText)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Brand.warn.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Some of these may not be real comments. Check each one before adding.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: const Text('Select positive'),
                      onPressed: () => setState(() {
                        _picked
                          ..clear()
                          ..addAll(positive);
                      }),
                    ),
                    ActionChip(
                      label: const Text('Select all'),
                      onPressed: () => setState(() {
                        _picked
                          ..clear()
                          ..addAll(visible);
                      }),
                    ),
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () => setState(_picked.clear),
                    ),
                    FilterChip(
                      label: const Text('Show positive only'),
                      selected: _onlyPositive,
                      showCheckmark: false,
                      onSelected: (v) => setState(() => _onlyPositive = v),
                    ),
                    FilterChip(
                      label: const Text('Positive first'),
                      selected: _positiveFirst,
                      showCheckmark: false,
                      onSelected: (v) => setState(() => _positiveFirst = v),
                    ),
                  ],
                ),
                const Divider(height: 22),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No positive comments here. Turn off “Show positive only” to see all.',
                      style: TextStyle(color: Brand.muted),
                    ),
                  ),
                for (final i in visible)
                  InkWell(
                    onTap: () => setState(() {
                      _picked.contains(i) ? _picked.remove(i) : _picked.add(i);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _picked.contains(i),
                            activeColor: Brand.primary,
                            onChanged: (_) => setState(() {
                              _picked.contains(i)
                                  ? _picked.remove(i)
                                  : _picked.add(i);
                            }),
                          ),
                          CommentAvatar(_found[i].author, radius: 14),
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
                                      _found[i].author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    StatusChip(
                                      _found[i].tone.label,
                                      _toneColor(_found[i].tone),
                                    ),
                                  ],
                                ),
                                Text(
                                  _found[i].text,
                                  style: const TextStyle(height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: _addByHand,
              child: const Text('Add more comments yourself'),
            ),
            // Developer tool: not shown to sellers.
            if (kDebugMode)
              TextButton(
                onPressed: _copyDebug,
                child: const Text('Copy debug info'),
              ),
          ],
        ),
      ],
    );
  }
}

/// The "add comments yourself" box: a name (optional) and a comment, added to
/// a list one by one. "Paste many at once" is there for a long copied list.
/// It owns its text controllers, so they are disposed with it.
class _AddCommentsSheet extends StatefulWidget {
  final String fallbackAuthor;
  const _AddCommentsSheet({required this.fallbackAuthor});

  @override
  State<_AddCommentsSheet> createState() => _AddCommentsSheetState();
}

class _AddCommentsSheetState extends State<_AddCommentsSheet> {
  final _name = TextEditingController();
  final _comment = TextEditingController();
  final _many = TextEditingController();
  final _added = <ParsedComment>[];
  bool _showMany = false;
  String? _error;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    _many.dispose();
    super.dispose();
  }

  void _addOne() {
    final text = _comment.text.trim();
    final name = _name.text.trim();
    // Both are needed: show what is missing, in red, under each box.
    if (name.isEmpty || text.isEmpty) {
      setState(() {
        _nameError = name.isEmpty ? 'Type the name first.' : null;
        _error = text.isEmpty ? 'Type the comment first.' : null;
      });
      return;
    }
    setState(() {
      _added.add(ParsedComment(shortName(name), text, classifyComment(text)));
      _name.clear();
      _comment.clear();
      _error = null;
      _nameError = null;
    });
  }

  void _addMany() {
    final parsed = parseCopiedComments(_many.text, widget.fallbackAuthor);
    if (parsed.isEmpty) {
      setState(() => _error = 'Paste the comments you copied first.');
      return;
    }
    setState(() {
      _added.addAll(parsed);
      _many.clear();
      _showMany = false;
      _error = null;
    });
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add comments yourself',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type who said it and what they said. Both are needed.',
              style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (!_showMany) ...[
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                decoration: InputDecoration(
                  label: reqLabel('Name'),
                  hintText: 'Maria Santos',
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _comment,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  label: reqLabel('Comment'),
                  hintText: 'Ang bango talaga!',
                  alignLabelWithHint: true,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _addOne,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add this comment'),
              ),
            ] else ...[
              const Text(
                'Paste the comments you copied. Put each name on its own line, then the comment under it.',
                style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _many,
                minLines: 5,
                maxLines: 10,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: 'Maria Santos\nAng bango talaga!\nJuan Dela Cruz\nSulit sa presyo',
                  alignLabelWithHint: true,
                  errorText: _error,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) _many.text = data!.text!;
                  },
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('Paste what I copied'),
                ),
              ),
              OutlinedButton(
                onPressed: _addMany,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Add these to the list'),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _showMany = !_showMany;
                _error = null;
              }),
              child: Text(
                _showMany ? 'Back to one at a time' : 'Paste many at once',
              ),
            ),
            if (_added.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Added so far (${_added.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _added.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommentAvatar(_added[i].author, radius: 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _added[i].author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _added[i].text,
                              style: const TextStyle(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove this comment',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _added.removeAt(i)),
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Brand.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _added.isEmpty
                  ? null
                  : () => Navigator.pop(context, List.of(_added)),
              child: Text(
                _added.isEmpty
                    ? 'Done'
                    : 'Done (${_added.length} comment${_added.length == 1 ? '' : 's'})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey placeholder rows that stand in for comments while they are read.
class _CommentSkeletons extends StatelessWidget {
  const _CommentSkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 36, height: 36, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 90 + i * 12.0, height: 12),
                      const SizedBox(height: 8),
                      const Skeleton(height: 12),
                      const SizedBox(height: 6),
                      Skeleton(width: 160 - i * 14.0, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
