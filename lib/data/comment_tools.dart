/// Turns text copied from a social post into separate comments, and suggests
/// which ones are positive. Works offline and is only a suggestion: the seller
/// always chooses what to add. Later this can be replaced by an AI model on the
/// server without changing the screens.
library;

import 'dart:convert';

enum CommentTone { positive, neutral, negative, spam }

extension CommentToneX on CommentTone {
  String get label => switch (this) {
    CommentTone.positive => 'Positive',
    CommentTone.neutral => 'Neutral',
    CommentTone.negative => 'Negative',
    CommentTone.spam => 'Spam',
  };
}

class ParsedComment {
  final String author;
  final String text;
  final CommentTone tone;
  const ParsedComment(this.author, this.text, this.tone);
}

// ------------------------------------------------------------------ tone

const _positiveWords = [
  'bango',
  'ganda',
  'galing',
  'sulit',
  'legit',
  'recommend',
  'love',
  'loved',
  'gusto',
  'thank',
  'salamat',
  'best',
  'good',
  'great',
  'amazing',
  'awesome',
  'nice',
  'worth',
  'satisfied',
  'fast',
  'agad',
  'swak',
  'astig',
  'solid',
  'trusted',
  'happy',
  'masarap',
  'sarap',
  'perfect',
  'excellent',
  'quality',
  'maayos',
  'okay',
  'bagay',
  'effective',
  'fresh',
  'sealed',
  'tumatagal',
  'mura',
  'sana all',
  'must try',
  'bibili ulit',
  'order ulit',
  'repeat',
  '👍',
  '❤',
  '😍',
  '💯',
  '🥰',
  '⭐',
  '🔥',
  '😊',
  '💚',
  '💖',
];

const _negativeWords = [
  'pangit',
  'scam',
  'peke',
  'fake',
  'sira',
  'sayang',
  'ayaw',
  'bad',
  'worst',
  'disappoint',
  'late',
  'reklamo',
  'poor',
  'broken',
  'expired',
  'nakakainis',
  'mabaho',
  'mahina',
  'cancel',
  'refund',
  'mali',
  'hindi ko gusto',
  'hindi maganda',
  'di maganda',
  'walang kwenta',
  'overpriced',
  'waste',
  'nasira',
  'kulang',
  'hindi dumating',
  'di dumating',
  'never again',
  'mabagal',
  'rude',
  'ripoff',
  '👎',
  '😡',
  '😠',
  '🤮',
];

const _spamHints = [
  'http://',
  'https://',
  'www.',
  'pa-follow',
  'pa follow',
  'follow me',
  'add me',
  'pm me',
  'dm me',
  'inbox me',
  'order now',
  'pa-like',
  'pa like',
  'free gift',
  'click here',
  'giveaway',
  'whatsapp',
  'telegram',
  'earn money',
];

CommentTone classifyComment(String text) {
  final t = text.toLowerCase();
  if (_spamHints.any(t.contains)) return CommentTone.spam;
  if (t.trim().length < 2) return CommentTone.spam;
  var pos = 0;
  var neg = 0;
  for (final w in _positiveWords) {
    if (t.contains(w)) pos++;
  }
  for (final w in _negativeWords) {
    if (t.contains(w)) neg++;
  }
  if (neg > 0 && neg >= pos) return CommentTone.negative;
  if (pos > 0) return CommentTone.positive;
  return CommentTone.neutral;
}

// --------------------------------------------------------------- parsing

final _timeToken = RegExp(
  r'^(just now|yesterday|today|\d+\s*(s|m|min|mins|h|hr|hrs|d|w|y|mo|sec|secs|hours?|days?|weeks?|months?|years?)(\s+ago)?|edited)$',
);
final _countToken = RegExp(
  r'^(\d+|\d+(\.\d+)?\s?[kKmM]|\d+\s*(likes?|repl(y|ies)|comments?|shares?|views?))$',
);
const _noiseWords = {
  'like',
  'reply',
  'share',
  'comment',
  'top fan',
  'author',
  'admin',
  'follow',
  'most relevant',
  'all comments',
  'newest',
  'see more',
  'view more comments',
  'write a comment…',
  'write a comment...',
  'write a public comment…',
  'write a public comment...',
  'hide',
  'report',
  'see translation',
  'rate this translation',
  'seen',
  'send',
  'verified',
  'top contributor',
  'rising fan',
  'fan',
  'reactions',
  'all reactions:',
};

/// Facebook draws its icons with private-use characters, which show up as
/// boxes. Drop them (and broken characters) from any text.
String cleanChars(String s) => s.replaceAll(RegExp(r'[-�​-‏]'), '').trim();

/// Removes a trailing time and button words that got glued on ("2hLikeReply").
String _stripTrail(String s) => s
    .replaceAll(
      RegExp(
        r's*(d+s?(s|m|h|d|w|y|mo|min|mins|hr|hrs)s*)?((like|reply|share|edited|see translation)s*)+$',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

/// Buttons, login prompts and page furniture that are never comments.
final _junkLine = RegExp(
  r'^(log ?in|log in to .*|sign ?up|sign in|open app|open facebook|open in app|create (new )?account|forgot (password|account)\??|not now|see more|see less|more|menu|home|watch|marketplace|notifications|search|send|there.s more to see|get more .*|continue|join|install|download app|use the app)$'
  r'|^see what .* sent$'
  r'|\band \d[\d,]* others?$'
  r'|\bupdated (their|his|her) (cover|profile)\b'
  r'|^(photo|video)\.?$'
  r'|^(log in|sign up) (to|for) .*'
  r'|^\d[\d.,]*\s?[kKmM]?\s*(comments?|shares?|likes?|reactions?|views?)$'
  r'|^\d{1,2}\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*(\s+\d{4})?$',
  caseSensitive: false,
);

bool _isNoiseLine(String line) {
  final l = cleanChars(line).toLowerCase().trim();
  if (l.isEmpty) return true;
  if (_junkLine.hasMatch(l)) return true;
  final tokens = l.split(RegExp(r'\s*[·•|]\s*'));
  return tokens.every(
    (t) =>
        t.isEmpty ||
        _noiseWords.contains(t) ||
        _timeToken.hasMatch(t) ||
        _countToken.hasMatch(t) ||
        RegExp(r'^view \d+ (more )?repl(y|ies)').hasMatch(t),
  );
}

bool _looksLikeName(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 40) return false;
  if (RegExp(r'[0-9!?.,:;@#/\\()\[\]]').hasMatch(t)) return false;
  final words = t.split(RegExp(r'\s+'));
  if (words.length > 4) return false;
  const particles = {'de', 'dela', 'del', 'la', 'ng', 'van', 'von', 'da', 'jr'};
  for (final w in words) {
    final first = w[0];
    final upper = first.toUpperCase() == first && first.toLowerCase() != first;
    if (!upper && !particles.contains(w.toLowerCase())) return false;
  }
  // A single short capitalised word is far more likely a comment ("Legit").
  return words.length >= 2;
}

/// "Maria Santos" -> "Maria S." so buyers see a short name, not a full one.
String shortName(String full) {
  final t = full.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return t;
  final words = t.split(' ');
  if (words.length < 2) return t;
  // Names often end in emoji or symbols ("Maria 🪼"): look at real words only.
  final letter = RegExp(r'^[\p{L}\p{N}]', unicode: true);
  final real = words.where(letter.hasMatch).toList();
  if (real.length < 2) return real.isEmpty ? t : real.first;
  final last = real.last;
  if (last.endsWith('.') && last.length <= 3) return t;
  // Take the first whole character (emoji and fancy letters are 2 code units).
  final initial = String.fromCharCode(last.runes.first).toUpperCase();
  return '${real.first} $initial.';
}

/// Reads pasted text. Understands "Name: comment" lines, and the plain text
/// Facebook gives when you copy comments (name line, comment line, then
/// "Like · Reply · 2h" noise, which is dropped).
List<ParsedComment> parseCopiedComments(String raw, String fallbackAuthor) {
  final lines = raw
      .split(RegExp(r'[\r\n]+'))
      .map(cleanChars)
      .where((e) => e.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];

  // ---- "Name: comment" per line
  final sep = RegExp(r'\s*[:：]\s+|\s+[-–—]\s+');
  final named = <ParsedComment>[];
  var matched = 0;
  for (final line in lines) {
    final m = sep.firstMatch(line);
    if (m != null && m.start > 0 && m.start <= 40 && m.end < line.length) {
      matched++;
      final text = line.substring(m.end).trim();
      named.add(
        ParsedComment(
          shortName(line.substring(0, m.start)),
          text,
          classifyComment(text),
        ),
      );
    } else {
      named.add(ParsedComment(fallbackAuthor, line, classifyComment(line)));
    }
  }
  if (matched * 10 >= lines.length * 6) return named;

  // ---- copied from Facebook: drop the buttons and timestamps first
  final clean = lines.where((l) => !_isNoiseLine(l)).toList();
  if (clean.isEmpty) return const [];

  final out = <ParsedComment>[];
  final evenPairs =
      clean.length >= 2 &&
      clean.length.isEven &&
      [for (var i = 0; i < clean.length; i += 2) clean[i]]
          .every(_looksLikeName);
  if (evenPairs) {
    for (var i = 0; i < clean.length; i += 2) {
      final text = clean[i + 1];
      out.add(ParsedComment(shortName(clean[i]), text, classifyComment(text)));
    }
    return out;
  }
  // Names and comments can't be told apart reliably: one comment per line.
  for (final l in clean) {
    out.add(ParsedComment(fallbackAuthor, l, classifyComment(l)));
  }
  return out;
}

// ---------------------------------------------------- grabbed from a page

/// "Comment by Maria Santos 3 days ago" -> "Maria Santos".
String authorFromLabel(String label) {
  var s = label.trim().replaceFirst(
    RegExp(r'^(comment|reply) by ', caseSensitive: false),
    '',
  );
  final cut = RegExp(
    r'\s+(\d+\s*(s|m|h|d|w|y|mo|min|mins|hr|hrs|sec|secs|hours?|days?|weeks?|months?|years?)\b|about\b|an?\s+(hour|minute|day|week|month|year)\b|yesterday|just now)',
    caseSensitive: false,
  ).firstMatch(s);
  if (cut != null) s = s.substring(0, cut.start);
  return s.trim();
}

/// Reads the JSON the grab script sends back:
/// `{articles: [{label?, author?, texts: [...]}], ...}`.
/// Only comments the page marked as comments are used. If it found none, the
/// result is empty: it never guesses from the rest of the page, so nothing but
/// real comments reaches the seller.
List<ParsedComment> parseGrabbedComments(
  String jsonText,
  String fallbackAuthor,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];

  final out = <ParsedComment>[];
  final seen = <String>{};
  final articles = decoded['articles'];
  if (articles is List) {
    for (final a in articles) {
      if (a is! Map) continue;
      final label = cleanChars((a['label'] ?? '').toString());
      final full = label.isNotEmpty
          ? authorFromLabel(label)
          : cleanChars((a['author'] ?? '').toString());
      final texts = <String>[
        for (final t in (a['texts'] is List ? a['texts'] as List : const []))
          _stripTrail(cleanChars(t.toString())),
      ];
      final body = texts
          .where(
            (t) =>
                t.isNotEmpty &&
                t.toLowerCase() != full.toLowerCase() &&
                !_isNoiseLine(t),
          )
          .join(' ')
          .trim();
      if (body.isEmpty) continue;
      final author = full.isEmpty ? fallbackAuthor : shortName(full);
      if (!seen.add('$author|$body')) continue;
      out.add(ParsedComment(author, body, classifyComment(body)));
    }
  }
  return out;
}

/// What a grab gave back, and whether it came from the page text (a guess)
/// rather than from elements the page marked as comments.
class GrabResult {
  final List<ParsedComment> comments;
  final bool fromPageText;
  const GrabResult(this.comments, this.fromPageText);
}

/// Reads a grab. Uses the comments the page marked as comments. If there are
/// none (for example the page also shows a login or sign-up box), it still
/// reads the page text, drops the junk lines, and splits what is left into
/// comments. Those are marked as a guess so the seller checks each one.
GrabResult readGrabbed(String jsonText, String fallbackAuthor) {
  final structured = parseGrabbedComments(jsonText, fallbackAuthor);
  if (structured.isNotEmpty) return GrabResult(structured, false);
  Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } catch (_) {
    return const GrabResult([], false);
  }
  final body = decoded is Map ? decoded['body'] : null;
  if (body is! String || body.trim().isEmpty) {
    return const GrabResult([], false);
  }
  // The page marks who commented. Use those names to find each comment.
  final rawNames = decoded is Map ? decoded['names'] : null;
  if (rawNames is List) {
    final byName = commentsByName(body, [
      for (final n in rawNames) n.toString(),
    ]);
    if (byName.isNotEmpty) return GrabResult(byName, false);
  }
  final seen = <String>{};
  final fromText = [
    for (final c in parseCopiedComments(body, fallbackAuthor))
      if (c.text.length >= 3 && seen.add('${c.author}|${c.text}')) c,
  ];
  return GrabResult(fromText, true);
}

/// Finds comments in page text when the page tells us who commented.
///
/// A comment is: the commenter's name on its own line, then the comment text,
/// then a "Reply" line. Everything after "Related Pages" or "Recent posts" is
/// ignored, because that is other posts, not this one.
List<ParsedComment> commentsByName(String body, List<String> names) {
  final known = {
    for (final n in names)
      if (cleanChars(n).isNotEmpty) cleanChars(n).toLowerCase(),
  };
  if (known.isEmpty) return const [];

  var lines = body
      .split(RegExp(r'[\r\n]+'))
      .map(cleanChars)
      .where((l) => l.isNotEmpty)
      .toList();

  const stopAt = {'related pages', 'recent posts', 'related videos'};
  final stop = lines.indexWhere((l) => stopAt.contains(l.toLowerCase()));
  if (stop >= 0) lines = lines.sublist(0, stop);

  final out = <ParsedComment>[];
  final seen = <String>{};
  for (var i = 0; i < lines.length; i++) {
    if (!known.contains(lines[i].toLowerCase())) continue;
    final parts = <String>[];
    var closed = false;
    for (var j = i + 1; j < lines.length && j <= i + 15; j++) {
      final l = lines[j];
      if (l.toLowerCase() == 'reply') {
        closed = true;
        break;
      }
      if (known.contains(l.toLowerCase())) break;
      if (!_isNoiseLine(l)) parts.add(l);
    }
    if (!closed || parts.isEmpty) continue;
    final text = parts.join(' ').trim();
    final author = shortName(lines[i]);
    if (text.length < 2 || !seen.add('$author|$text')) continue;
    out.add(ParsedComment(author, text, classifyComment(text)));
  }
  return out;
}
