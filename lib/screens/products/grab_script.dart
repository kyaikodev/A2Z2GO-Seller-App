/// Scripts that run inside the hidden page the app uses to read comments.
///
/// [grabScript] waits only until comments show up (no fixed pauses), scrolls
/// and presses "view more comments" until nothing new appears, then collects
/// the comments and sends them back through the `A2ZGrab` channel as JSON:
/// `{articles: [{label?, author?, texts: [...]}], names: [...], body: "...",
/// loginWall: bool}`.
///
/// [debugScript] returns a short description of how the page is built, which
/// the seller can copy and send over when a layout is not understood yet.
const grabScript = r'''
(async function () {
  var send = function (obj) {
    try { A2ZGrab.postMessage(JSON.stringify(obj)); } catch (e) {}
  };
  try {
    var sleep = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
    var isTikTok = /tiktok\.com$/.test(location.hostname);
    var isInstagram = /instagram\.com$/.test(location.hostname);
    var isYouTube = /youtube\.com$/.test(location.hostname);
    // "Quick" run: the app asks for whatever is on the page right now, no waiting.
    var quick = !!window.__a2zQuick;
    var startedAt = Date.now();
    function timeLeft() { return 45000 - (Date.now() - startedAt); }

    // Poll until cond() is true, checking often; gives up after maxMs.
    async function waitFor(cond, maxMs, step) {
      // Real time, not the sum of the pauses: checking the page can itself be
      // slow on a phone, which used to stretch a 25 s wait to over a minute.
      var end = Date.now() + maxMs;
      while (Date.now() < end) {
        if (cond()) return true;
        await sleep(step);
      }
      return cond();
    }

    // TikTok and Instagram lay out as a phone page (no comments list) unless
    // the screen looks wide.
    if (isTikTok || isInstagram) {
      var vp = document.querySelector('meta[name="viewport"]');
      if (!vp) {
        vp = document.createElement('meta');
        vp.setAttribute('name', 'viewport');
        (document.head || document.documentElement).appendChild(vp);
      }
      vp.setAttribute('content', 'width=1280');
      await sleep(350);
    }

    var MORE = /^(view|see|show)\s+(\d[\d,]*\s+)?(more|previous|all)\b.*(comment|repl)|^view\s+\d[\d,]*\s+(more\s+)?repl|^\d[\d,]*\s+repl(y|ies)$|^(see|show)\s+more\s+comments|^more replies|^load\s+more\s+comments/i;

    function clickMore() {
      var n = 0;
      var els = document.querySelectorAll(
        'div[role="button"], span[role="button"], button, [data-sigil="more-comments"], [data-e2e="view-more-1"], [data-e2e^="comment-reply-view"]'
      );
      for (var i = 0; i < els.length; i++) {
        var t = (els[i].innerText || '').trim();
        if (t && t.length < 70 && MORE.test(t)) {
          try { els[i].click(); n++; } catch (e) {}
        }
      }
      return n;
    }

    // TikTok's page is a feed: the linked video plus the next ones. Only the
    // linked video's own box may be used, and the feed itself must never be
    // scrolled (that moves on to another video and its comments).
    var tiktokId = isTikTok ? ((location.pathname.match(/\/video\/(\d+)/) || [])[1] || null) : null;
    function tiktokItem() {
      var items = document.querySelectorAll('[data-e2e="recommend-list-item-container"]');
      for (var i = 0; i < items.length; i++) {
        if (items[i].innerHTML.indexOf(tiktokId) >= 0) return items[i];
      }
      return null;
    }

    // Areas of the page that scroll by themselves (e.g. a comments panel).
    function findScrollers() {
      var res = [];
      var divs = document.querySelectorAll('div');
      for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        if (d.clientHeight > 100 && d.scrollHeight > d.clientHeight + 200) {
          var oy = getComputedStyle(d).overflowY;
          if (oy !== 'auto' && oy !== 'scroll') continue;
          if (isTikTok && (!d.querySelector('[data-e2e^="comment-level"]') ||
              d.querySelector('[data-e2e="recommend-list-item-container"]'))) continue;
          res.push(d);
        }
      }
      return res;
    }
    function scrollAll(list) {
      if (!isTikTok) window.scrollTo(0, document.documentElement.scrollHeight);
      for (var i = 0; i < list.length; i++) list[i].scrollTop = list[i].scrollHeight;
    }

    // Instagram: every comment has a "Reply" button.
    function igReplyButtons() {
      var res = [];
      var btns = document.querySelectorAll('div[role="button"]');
      for (var i = 0; i < btns.length; i++) {
        if ((btns[i].innerText || '').trim() === 'Reply') res.push(btns[i]);
      }
      return res;
    }

    // Instagram: a comment is the largest block around its Reply button that
    // holds no other Reply button. Its lines read: name, [Verified,] time,
    // the comment, then likes and Reply.
    function igComments() {
      var res = [];
      var btns = igReplyButtons();
      for (var i = 0; i < btns.length && res.length < 300; i++) {
        var root = btns[i], cur = btns[i].parentElement;
        while (cur) {
          var others = 0, inner = cur.querySelectorAll('div[role="button"]');
          for (var j = 0; j < inner.length; j++) {
            if ((inner[j].innerText || '').trim() === 'Reply') others++;
          }
          if (others > 1) break;
          root = cur;
          cur = cur.parentElement;
        }
        var lines = (root.innerText || '').split('\n'), clean = [];
        for (var q = 0; q < lines.length; q++) {
          var t = lines[q].trim();
          if (t) clean.push(t);
        }
        var at = -1;
        for (var w = 1; w < Math.min(clean.length, 4); w++) {
          if (/^\d+\s*[smhdwy]$/i.test(clean[w])) { at = w; break; }
        }
        if (at < 0) continue;
        var texts = [];
        for (var z = at + 1; z < clean.length; z++) {
          if (!/^(like|\d[\d,.]*[kKmM]?\s+likes?|reply|view\s+\d+\s+repl(y|ies)|hide\s+repl(y|ies))$/i.test(clean[z])) texts.push(clean[z]);
        }
        if (texts.length) res.push({ author: clean[0], texts: [texts.join(' ')] });
      }
      return res;
    }

    // Counts the things that mean "a comment is here" on any supported page.
    function count() {
      return document.querySelectorAll(
        '[role="article"][aria-label], [data-sigil~="comment"], a[href*="comment_id="], ' +
        '[aria-label^="Profile, "], [aria-label$=" commented"], ' +
        'ytd-comment-thread-renderer, [data-e2e^="comment-level"]'
      ).length + (isInstagram ? igReplyButtons().length : 0);
    }

    function clickByText(re, selector) {
      var els = document.querySelectorAll(selector);
      for (var i = 0; i < els.length; i++) {
        var t = (els[i].innerText || '').trim();
        if (!t || t.length >= 30 || !re.test(t)) continue;
        var inner = false;
        for (var c = 0; c < els[i].children.length; c++) {
          if ((els[i].children[c].innerText || '').trim() === t) { inner = true; break; }
        }
        if (inner) continue;
        try { els[i].click(); return true; } catch (e) {}
      }
      return false;
    }

    // TikTok hides its comments until you close the tip, tap the comment
    // button and open the "Comments" tab. Do what a person would.
    var iconClicks = 0, lastIconClick = 0;
    function openTikTokComments() {
      if (!isTikTok) return;
      if (document.querySelectorAll('[data-e2e^="comment-level"]').length > 0) return;
      clickByText(/^got it$/i, 'button, [role="button"], div, span');
      // The panel opens on "You may like": switch to the "Comments" tab.
      if (clickByText(/^comments?(\s*\(?\d[\d,.]*[kKmM]?\)?)?$/i, '[role="tab"], [role="tab"] *, button, button *, div, span, p')) return;
      // The button toggles the panel, so press it only a few times, spaced out.
      var now = Date.now();
      if (iconClicks >= 3 || now - lastIconClick < 2500) return;
      var mine = tiktokId ? tiktokItem() : document;
      if (!mine) return; // the linked video is not on the page yet
      var icon =
        mine.querySelector('[data-e2e="comment-icon"]') ||
        mine.querySelector('[aria-label^="Read or add comments"]') ||
        mine.querySelector('button[aria-label*="comments" i]');
      if (icon) {
        iconClicks++; lastIconClick = now;
        try { (icon.closest('button') || icon).click(); } catch (e) {}
      }
    }

    // TikTok: wait until the linked video itself is on the page.
    if (tiktokId && !quick) await waitFor(function () { return !!tiktokItem(); }, 15000, 250);

    // YouTube only loads its comments once their section is on screen, and the
    // page is still short while it loads, so scrolling to the bottom is not
    // enough. Bring the comments section into view and wait for it (slow
    // phone connections need a while).
    if (isYouTube && !quick) {
      await waitFor(function () {
        var section = document.querySelector('ytd-comments');
        if (section) section.scrollIntoView({ block: 'start' });
        return count() > 0;
      }, 20000, 500);
    }

    // 1) Wait only until comments appear (not a fixed pause).
    openTikTokComments();
    await waitFor(function () { openTikTokComments(); return count() > 0; }, quick ? 0 : (isTikTok ? 12000 : 5000), 250);

    // 2) Scroll and press "view more" until nothing new shows up.
    var scrollers = findScrollers();
    var last = count(), still = 0;
    for (var round = 0; round < 10; round++) {
      if (quick || timeLeft() < 3000) break; // out of time: read what is loaded
      var before = count();
      scrollAll(scrollers);
      clickMore();
      await waitFor(function () { return count() > before; }, isInstagram ? 2500 : 1000, 150);
      var c = count();
      if (c === last) { still++; } else { still = 0; }
      last = c;
      if (still >= (isInstagram ? 3 : 2)) break;
      if (round % 3 === 2) scrollers = findScrollers();
    }

    var out = [];
    var seenBox = [];

    // Facebook (current layout): comments are articles labelled "Comment by NAME ..."
    var arts = document.querySelectorAll('[role="article"]');
    for (var a = 0; a < arts.length; a++) {
      var art = arts[a];
      var label = art.getAttribute('aria-label') || '';
      if (!/^(comment|reply) by /i.test(label)) continue;
      var texts = [];
      var blocks = art.querySelectorAll('[dir="auto"]');
      for (var b = 0; b < blocks.length; b++) {
        if (blocks[b].closest('[role="article"]') === art) {
          var tx = (blocks[b].innerText || '').trim();
          if (tx) texts.push(tx);
        }
      }
      out.push({ label: label, texts: texts });
      seenBox.push(art);
    }

    // Facebook (older mobile layout)
    var olds = document.querySelectorAll('[data-sigil~="comment"]');
    for (var o = 0; o < olds.length; o++) {
      var body = olds[o].querySelector('[data-sigil="comment-body"]');
      var who = olds[o].querySelector('h3, a');
      if (body) {
        out.push({
          author: who ? (who.innerText || '').trim() : '',
          texts: [(body.innerText || '').trim()]
        });
        seenBox.push(olds[o]);
      }
    }

    // Facebook, any layout: every comment has a time link that points at its
    // own comment (?comment_id=...). The comment is the largest block around
    // that link that holds no other comment's link.
    if (out.length === 0) {
      var links = document.querySelectorAll('a[href*="comment_id="]');
      for (var l = 0; l < links.length; l++) {
        var own = (links[l].innerText || '').trim().length;
        var box = null;
        var cur = links[l].parentElement;
        for (var up = 0; up < 10 && cur; up++, cur = cur.parentElement) {
          if (cur.querySelectorAll('a[href*="comment_id="]').length > 1) break;
          if ((cur.innerText || '').trim().length > own + 12) box = cur;
        }
        if (!box || seenBox.indexOf(box) !== -1) continue;
        seenBox.push(box);
        var lines = (box.innerText || '').split('\n');
        var clean = [];
        for (var q = 0; q < lines.length; q++) {
          var ln = lines[q].trim();
          if (ln) clean.push(ln);
        }
        if (clean.length >= 2) out.push({ author: clean[0], texts: clean.slice(1) });
      }
    }

    // YouTube (desktop layout)
    var yts = document.querySelectorAll('ytd-comment-thread-renderer');
    var ytWithText = 0, ytWithAuthor = 0;
    for (var y = 0; y < yts.length; y++) {
      var yt = yts[y].querySelector('#content-text');
      var ya = yts[y].querySelector('#author-text');
      if (yt) ytWithText++;
      if (ya) ytWithAuthor++;
      if (yt) {
        out.push({
          author: ya ? (ya.innerText || '').trim().replace(/^@/, '') : '',
          texts: [(yt.innerText || '').trim()]
        });
      }
    }

    // TikTok
    var tks = document.querySelectorAll('[data-e2e^="comment-level"]');
    for (var k = 0; k < tks.length; k++) {
      var root = tks[k].closest('[class*="CommentItem"]') ||
        (tks[k].parentElement && tks[k].parentElement.parentElement);
      var tu = root ? root.querySelector('[data-e2e^="comment-username"]') : null;
      out.push({
        author: tu ? (tu.innerText || '').trim() : '',
        texts: [(tks[k].innerText || '').trim()]
      });
    }

    if (isInstagram) {
      var igs = igComments();
      for (var g = 0; g < igs.length; g++) out.push(igs[g]);
    }

    // Names of the people who commented, from labels such as
    // "Profile, Maria Santos" or "Maria Santos commented".
    var names = [];
    var labelled = document.querySelectorAll('[aria-label^="Profile, "], [aria-label$=" commented"], [aria-label$=" replied"]');
    for (var n = 0; n < labelled.length; n++) {
      var lab = labelled[n].getAttribute('aria-label') || '';
      var m = lab.match(/^Profile, (.+)$/) || lab.match(/^(.+) (commented|replied)$/);
      if (m) {
        var nm = m[1].trim();
        if (nm && names.indexOf(nm) === -1) names.push(nm);
      }
    }

    // The feed moved on to another video: its comments are not the linked ones.
    if (tiktokId && location.href.indexOf(tiktokId) < 0) out.length = 0;

    var pageText = document.body.innerText || '';
    var loginWall =
      !!document.querySelector('input[type="password"], input[name="pass"]') ||
      /(log in|sign in|log into) (to|for) (continue|facebook|see|connect|instagram|tiktok)/i.test(pageText) ||
      /\bcreate new account\b/i.test(pageText);

    send({
      articles: out,
      loginWall: loginWall,
      names: names,
      body: pageText.slice(0, 60000),
      host: location.hostname,
      // Shown on the failed screen so a problem can be understood from it.
      diag: {
        read: out.length,
        boxes: count(),
        ytBoxes: yts.length,
        ytWithText: ytWithText,
        ytWithAuthor: ytWithAuthor,
        wide: window.innerWidth
      }
    });
  } catch (err) {
    send({ error: String(err), articles: [], loginWall: false });
  }
})();
''';

/// Describes how the current page is built (no secrets): screen width,
/// element counts, the most common labels, buttons, and a few sample blocks.
/// Returns a JSON string.
const debugScript = r'''
(function () {
  var o = {
    url: location.href,
    title: document.title,
    width: window.innerWidth,
    ratio: window.devicePixelRatio
  };
  function cnt(s) { try { return document.querySelectorAll(s).length; } catch (e) { return -1; } }
  o.counts = {
    article: cnt('[role="article"]'),
    articleLabeled: cnt('[role="article"][aria-label]'),
    commentBy: cnt('[aria-label^="Comment by"]'),
    oldSigil: cnt('[data-sigil~="comment"]'),
    commentIdLinks: cnt('a[href*="comment_id="]'),
    profileLabels: cnt('[aria-label^="Profile, "]'),
    dirAuto: cnt('[dir="auto"]'),
    password: cnt('input[type="password"]'),
    youtube: cnt('ytd-comment-thread-renderer'),
    tiktok: cnt('[data-e2e^="comment-level"]'),
    tiktokIcon: cnt('[data-e2e="comment-icon"]'),
    readComments: cnt('[aria-label^="Read or add comments"]')
  };
  var e2e = {};
  var tagged = document.querySelectorAll('[data-e2e]');
  for (var t = 0; t < tagged.length; t++) {
    var k = tagged[t].getAttribute('data-e2e') || '';
    if (/comment|reply|tab|login|panel|drawer|popup|modal/i.test(k)) e2e[k] = (e2e[k] || 0) + 1;
  }
  o.e2e = e2e;
  var labels = {};
  var withLabel = document.querySelectorAll('[aria-label]');
  for (var i = 0; i < withLabel.length; i++) {
    var l = (withLabel[i].getAttribute('aria-label') || '').replace(/\d+/g, '#').slice(0, 40);
    labels[l] = (labels[l] || 0) + 1;
  }
  o.labels = Object.keys(labels).map(function (x) { return [x, labels[x]]; })
    .sort(function (a, b) { return b[1] - a[1]; }).slice(0, 25);
  var buttons = [];
  var bs = document.querySelectorAll('button, [role="button"], [role="tab"]');
  for (var b = 0; b < bs.length && buttons.length < 25; b++) {
    var txt = (bs[b].getAttribute('aria-label') || bs[b].innerText || '').replace(/\s+/g, ' ').trim().slice(0, 40);
    if (txt) buttons.push(txt);
  }
  o.buttons = buttons;
  var samples = [];
  var links = document.querySelectorAll('a[href*="comment_id="]');
  for (var s = 0; s < Math.min(3, links.length); s++) {
    var c = links[s];
    for (var u = 0; u < 4 && c.parentElement; u++) c = c.parentElement;
    samples.push((c.outerHTML || '').replace(/\s+/g, ' ').slice(0, 700));
  }
  o.sampleHtml = samples;
  var ytFirst = document.querySelector('ytd-comment-thread-renderer');
  o.ytSample = ytFirst ? (ytFirst.outerHTML || '').replace(/\s+/g, ' ').slice(0, 1800) : null;
  o.body = (document.body.innerText || '').slice(0, 1500);
  return JSON.stringify(o);
})()
''';
