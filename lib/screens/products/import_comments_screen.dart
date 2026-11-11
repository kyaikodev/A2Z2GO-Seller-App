import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/comment_tools.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/social.dart';
import 'grab_script.dart';
import 'proof_screen.dart' show CommentAvatar;

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
  static const _mobileAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  // YouTube only shows its comment list on the desktop layout.
  static const _desktopAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  WebViewController? _web;
  _Mode _mode = _Mode.reading;
  String _message = '';
  List<ParsedComment> _found = [];
  final Set<int> _picked = {};
  bool _onlyPositive = false;
  bool _fromText = false;
  bool _offline = false;
  bool _started = false;
  Timer? _timeout;
  Timer? _startTimer;

  String get _fallback => '${widget.post.platform.label} user';

  /// YouTube and TikTok only show their comments on the computer layout; the
  /// phone layout hides them behind "Open app".
  bool get _needsDesktopView =>
      widget.post.platform == SocialPlatform.youtube ||
      widget.post.platform == SocialPlatform.tiktok;

  @override
  void initState() {
    super.initState();
    _web = _makeController();
    if (_web == null) {
      _mode = _Mode.failed;
      _message = 'Automatic reading needs the phone app. You can paste comments instead.';
    } else {
      // Start on its own even if the page is slow to say it has loaded.
      _startTimer = Timer(const Duration(seconds: 8), _startOnce);
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
        ..setUserAgent(_needsDesktopView ? _desktopAgent : _mobileAgent)
        ..addJavaScriptChannel('A2ZGrab', onMessageReceived: _onGrabbed)
        ..setNavigationDelegate(
          NavigationDelegate(
            // Start reading as soon as the page is mostly there. The script
            // itself waits only until comments show up, so there is no need to
            // wait for ads and videos to finish.
            onProgress: (p) {
              if (p >= 55) _startOnce();
            },
            onPageFinished: (_) => _startOnce(),
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
        )
        ..loadRequest(Uri.parse(widget.post.url));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- reading

  void _fail(String message, {bool offline = false}) {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() {
      _mode = _Mode.failed;
      _message = message;
      _offline = offline;
    });
  }

  void _startOnce() {
    if (!_started && mounted && _mode == _Mode.reading) {
      _started = true;
      _grab();
    }
  }

  Future<void> _grab() async {
    final web = _web;
    if (web == null || !mounted) return;
    setState(() => _mode = _Mode.reading);
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 100), () {
      if (mounted && _mode == _Mode.reading) _fail('That took too long.');
    });
    try {
      await web.runJavaScript(grabScript);
    } catch (_) {
      _fail('Could not read this page.');
    }
  }

  Future<void> _tryAgain() async {
    final web = _web;
    if (web == null) return;
    setState(() {
      _mode = _Mode.reading;
      _started = false;
      _offline = false;
    });
    await web.loadRequest(Uri.parse(widget.post.url));
  }

  void _onGrabbed(JavaScriptMessage message) {
    if (!mounted || _mode != _Mode.reading) return;
    _timeout?.cancel();
    // Always try to read, even if a login or sign-up box is on the page.
    final result = readGrabbed(message.message, _fallback);
    if (result.comments.isNotEmpty) {
      _show(result.comments, fromText: result.fromPageText);
    } else {
      _fail('No comments were found on this post.');
    }
  }

  void _show(List<ParsedComment> comments, {bool fromText = false}) {
    setState(() {
      _fromText = fromText;
      _found = comments;
      _picked
        ..clear()
        ..addAll([
          for (var i = 0; i < comments.length; i++)
            if (comments[i].tone == CommentTone.positive) i,
        ]);
      _onlyPositive = false;
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
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showMsg(context, 'Debug info copied. Paste it to your helper.');
    }
  }

  Future<void> _pasteSheet() async {
    final result = await showModalBottomSheet<List<ParsedComment>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PasteSheet(fallbackAuthor: _fallback),
    );
    if (result != null && mounted) _show(result);
  }

  // ------------------------------------------------------------------ adding

  List<int> _visible() => [
    for (var i = 0; i < _found.length; i++)
      if (!_onlyPositive || _found[i].tone == CommentTone.positive) i,
  ];

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
                'Scroll to the comments if needed, then tap Grab comments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _grab,
                child: const Text('Grab comments'),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                  _message.isEmpty ? 'Could not get comments.' : _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                if (_web != null) ...[
                  FilledButton(
                    onPressed: _tryAgain,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _mode = _Mode.showPage),
                    child: const Text('Show the page'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: _pasteSheet,
                  child: const Text('Paste comments instead'),
                ),
                TextButton(
                  onPressed: () => openLink(context, widget.post.url),
                  child: Text('Open in ${widget.post.platform.label}'),
                ),
                TextButton(
                  onPressed: _copyDebug,
                  child: const Text('Copy debug info'),
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
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5),
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
                      'Read from the page text. It may include things that are not comments, so check each one before adding.',
                      style: TextStyle(fontSize: 12.5),
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
              onPressed: _pasteSheet,
              child: const Text('Paste more comments'),
            ),
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

/// The backup paste box. It owns its text controller, so the controller is
/// only disposed once the sheet is completely gone.
class _PasteSheet extends StatefulWidget {
  final String fallbackAuthor;
  const _PasteSheet({required this.fallbackAuthor});

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
            const Text(
              'Paste comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Copy comments from the post and paste them here. We split them up and pick the positive ones. '
              'You can also type one per line as “Name: comment”.',
              style: TextStyle(color: Brand.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Maria Santos\nAng bango talaga!\nLike · Reply · 2h',
                alignLabelWithHint: true,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) _text.text = data!.text!;
                },
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Paste from clipboard'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final parsed = parseCopiedComments(
                  _text.text,
                  widget.fallbackAuthor,
                );
                if (parsed.isEmpty) {
                  showMsg(context, 'Paste at least one comment.', error: true);
                  return;
                }
                Navigator.pop(context, parsed);
              },
              child: const Text('Find comments'),
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
