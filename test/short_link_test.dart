import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:a2z2go_seller/data/link_import.dart';

void main() {
  test('the desktop identity uses the real Chrome version of the phone', () {
    const phone =
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Version/4.0 Chrome/131.0.6778.39 Mobile Safari/537.36';
    final d = desktopAgentLike(phone);
    expect(d, contains('Chrome/131.0.6778.39'));
    expect(d, contains('X11; Linux x86_64'));
    expect(d, isNot(contains('Mobile')));
    expect(
      desktopAgentLike(null),
      desktopBrowserAgent,
    ); // no version: fall back
  });

  test('a TikTok page gives its real caption, never "Make Your Day"', () {
    const html =
        '<html><head><title>TikTok - Make Your Day</title></head><body>'
        '<script>{"desc":"Bathsoap na anti bacterial \u0026 mabango #soap","x":1}</script>'
        '</body></html>';
    final info = parseLinkInfo('https://www.tiktok.com/@u/video/1', html);
    expect(info.title, 'Bathsoap na anti bacterial & mabango #soap');
    // no caption in the page: the generic title is dropped, not shown
    final bare = parseLinkInfo(
      'https://www.tiktok.com/@u/video/1',
      '<title>TikTok - Make Your Day</title>',
    );
    expect(bare.title, isNull);
    expect(usefulCaption('TikTok - Make Your Day'), '');
    expect(usefulCaption('Shield soap'), 'Shield soap');
  });

  test(
    'the Instagram numbers lead-in is dropped, the real caption is kept',
    () {
      expect(
        usefulCaption(
          '381K likes, 7,520 comments - instagram on November 11, 2026: "@josh hikes for views like these"',
        ),
        '@josh hikes for views like these',
      );
      // no caption in it: show nothing rather than the numbers
      expect(
        usefulCaption(
          '381K likes, 7,520 comments - instagram on November 11, 2026',
        ),
        '',
      );
      expect(usefulCaption('Shield soap'), 'Shield soap');
    },
  );

  test('only share links that redirect are treated as short links', () {
    bool s(String u) => isShortLink(Uri.parse(u));
    expect(s('https://vt.tiktok.com/ZSpursJbg/'), true);
    expect(s('https://vm.tiktok.com/ZSabc/'), true);
    expect(s('https://www.tiktok.com/t/ZTabc/'), true);
    expect(s('https://fb.watch/abc/'), true);
    expect(s('https://www.tiktok.com/@u/video/123'), false);
    expect(s('https://www.facebook.com/x/posts/1'), false);
  });

  test(
    'a TikTok short link is followed to the real video, without tracking',
    () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add(req.url.toString());
        if (req.url.host == 'vt.tiktok.com') {
          return http.Response(
            '',
            301,
            headers: {
              'location': 'https://www.tiktok.com/@maker/video/7555122895148584199?_r=1&_t=ZS-xyz',
            },
          );
        }
        return http.Response('<html></html>', 200);
      });
      final real = await resolveShortLink(
        'https://vt.tiktok.com/ZSpursJbg/',
        client: client,
      );
      expect(real, 'https://www.tiktok.com/@maker/video/7555122895148584199');
      expect(seen.length, 2);
    },
  );

  test(
    'normal links are returned as they are, and failures keep the link',
    () async {
      final client = MockClient((req) async => throw Exception('offline'));
      expect(
        await resolveShortLink(
          'https://www.facebook.com/x/posts/1',
          client: client,
        ),
        'https://www.facebook.com/x/posts/1',
      );
      expect(
        await resolveShortLink(
          'https://vt.tiktok.com/ZSpursJbg/',
          client: client,
        ),
        'https://vt.tiktok.com/ZSpursJbg/', // could not follow it: keep the original
      );
    },
  );
}
