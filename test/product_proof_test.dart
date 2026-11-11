import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a2z2go_seller/core/format.dart';
import 'package:a2z2go_seller/data/link_import.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/store.dart';
import 'package:a2z2go_seller/data/comment_tools.dart';

void main() {
  group('link import', () {
    test('reads a shop product page from JSON-LD', () {
      const html = '''
<html><head><title>Ignored title</title>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Product",
 "name":"Pride Fabric Conditioner &amp; Powder 2kg",
 "description":"Sakura Blossom scent",
 "image":["https://cdn.example.com/a/pride.png","/media/other.png"],
 "brand":{"@type":"Brand","name":"Pride"},
 "offers":{"@type":"Offer","price":"215.30","priceCurrency":"PHP"}}
</script></head><body></body></html>''';
      final i = parseLinkInfo('https://shop.example.com/p/1', html);
      expect(i.title, 'Pride Fabric Conditioner & Powder 2kg');
      expect(i.brand, 'Pride');
      expect(i.price, 215.30);
      expect(i.images, [
        'https://cdn.example.com/a/pride.png',
        'https://shop.example.com/media/other.png',
      ]);
    });

    test(
      'falls back to OpenGraph tags (social posts) and decodes entities',
      () {
        const html = '''
<meta property="og:title" content="Pride">
<meta content="Ang bango &amp; tagal! &#128154;" property="og:description">
<meta property="og:image" content="https://img.example.com/x.jpg?a=1&amp;b=2">''';
        final i = parseLinkInfo(
          'https://www.facebook.com/PridePHL/posts/1',
          html,
        );
        expect(i.title, 'Pride');
        expect(i.description, 'Ang bango & tagal! \u{1F49A}');
        expect(i.image, 'https://img.example.com/x.jpg?a=1&b=2');
        expect(i.price, isNull);
      },
    );

    test('the same photo at two cache sizes is listed once', () {
      const html = '''
<script type="application/ld+json">{"@type":"Product","name":"X",
"image":"https://m.example.com/cache/aaa/p/x.png"}</script>
<meta property="og:image" content="https://m.example.com/cache/bbb/p/x.png">''';
      expect(parseLinkInfo('https://m.example.com/x', html).images.length, 1);
    });

    test('rejects links that are not http(s)', () async {
      expect(
        () => fetchLinkInfo('not a link'),
        throwsA(isA<LinkImportException>()),
      );
      expect(
        () => fetchLinkInfo('file:///etc/passwd'),
        throwsA(isA<LinkImportException>()),
      );
    });
  });

  group('platforms and comments', () {
    test('detects the platform from the link', () {
      SocialPlatform f(String u) => SocialPlatformX.fromUrl(u);
      expect(
        f('https://www.facebook.com/PridePHL/posts/1'),
        SocialPlatform.facebook,
      );
      expect(f('https://fb.watch/abc'), SocialPlatform.facebook);
      expect(f('https://www.instagram.com/p/xyz'), SocialPlatform.instagram);
      expect(f('https://vt.tiktok.com/ZS123'), SocialPlatform.tiktok);
      expect(f('https://youtu.be/abc'), SocialPlatform.youtube);
      expect(f('https://example.com/post'), SocialPlatform.link);
      expect(f('https://notfacebook.com/x'), SocialPlatform.link);
    });

    test(
      'pasted comments: "Name: text" per line, nameless lines get a fallback',
      () {
        final r = parseCopiedComments(
          'Maria S.: Ang bango talaga!\n\nJuan D. - Legit, dumating agad.\nGaling ng produkto',
          'Facebook user',
        );
        expect(r.length, 3);
        expect(r[0].author, 'Maria S.');
        expect(r[0].text, 'Ang bango talaga!');
        expect(r[1].author, 'Juan D.');
        expect(r[2].author, 'Facebook user');
        expect(r[2].text, 'Galing ng produkto');
      },
    );

    test('comments copied straight from Facebook are split and cleaned', () {
      const copied = '''
Maria Santos
Ang bango talaga, tumatagal pa sa damit!
Like · Reply · 2h
Juan Dela Cruz
Legit, dumating agad at sealed ang pack.
Like
Reply
3d
Ana Reyes
Pangit, sira agad
5h
Pedro Lim
pa-follow po https://spam.example.com
1w
''';
      final r = parseCopiedComments(copied, 'Facebook user');
      expect(r.map((e) => e.author).toList(), [
        'Maria S.',
        'Juan C.',
        'Ana R.',
        'Pedro L.',
      ]);
      expect(r[0].text, 'Ang bango talaga, tumatagal pa sa damit!');
      expect(r[0].tone, CommentTone.positive);
      expect(r[1].tone, CommentTone.positive);
      expect(r[2].tone, CommentTone.negative);
      expect(r[3].tone, CommentTone.spam);
      // none of Facebook's buttons or timestamps leak in as comments
      expect(r.any((e) => e.text == 'Like' || e.text == '3d'), false);
    });

    test('positive filter understands English and Tagalog', () {
      CommentTone t(String s) => classifyComment(s);
      expect(t('Ang bango talaga!'), CommentTone.positive);
      expect(t('Sulit! Bibili ulit ako ❤'), CommentTone.positive);
      expect(t('Legit seller, thank you'), CommentTone.positive);
      expect(t('Scam, hindi dumating'), CommentTone.negative);
      expect(t('Worst product ever'), CommentTone.negative);
      expect(t('Magkano po?'), CommentTone.neutral);
      expect(t('dm me for promo'), CommentTone.spam);
    });

    test(
      'TikTok-style names with emoji and fancy letters are shortened safely',
      () {
        expect(shortName('Batang Nobenta 🪼'), 'Batang N.');
        expect(shortName('𝓑𝓪𝓽𝓪𝓷𝓰 𝓝𝓸𝓫𝓮𝓷𝓽𝓪 🪼'), '𝓑𝓪𝓽𝓪𝓷𝓰 𝓝.');
        expect(shortName('maryannshop28'), 'maryannshop28');
        expect(shortName('LDNEW WAY Olshop'), 'LDNEW O.');
        expect(shortName('Miss 🪼'), 'Miss');
      },
    );

    test('TikTok comments grabbed with names are read as they are', () {
      const json =
          r'{"articles":[{"author":"Batang Nobenta 🪼","texts":["Gamit ko to dati sobrang bango"]},{"author":"Babyko Sikulot","texts":["napaka effective neto to fight bacteria"]},{"author":"maryannshop28","texts":["maganda ito na sabon moisturizing sa skin"]}],"names":[],"body":"icon31"}';
      final r = readGrabbed(json, 'TikTok user');
      expect(r.fromPageText, false);
      expect(r.comments.map((c) => c.author).toList(), [
        'Batang N.',
        'Babyko S.',
        'maryannshop28',
      ]);
      expect(r.comments[1].tone, CommentTone.positive);
    });

    test('long names are shortened for buyers', () {
      expect(shortName('Maria Santos'), 'Maria S.');
      expect(shortName('Juan'), 'Juan');
      expect(shortName('Ana Maria Dela Cruz'), 'Ana C.');
      expect(shortName('Maria S.'), 'Maria S.');
    });

    test('comments grabbed from a page become suggestions', () {
      const json =
          '{"articles":[{"label":"Comment by Maria Santos 3 days ago","texts":["Maria Santos","Ang bango talaga, tumatagal pa sa damit!"]},'
          '{"label":"Reply by Juan Dela Cruz 2 days ago","texts":["Juan Dela Cruz","Legit, dumating agad!"]},'
          '{"label":"Comment by Ana Reyes about an hour ago","texts":["Ana Reyes","Pangit, sira agad"]},'
          '{"author":"PedroLim","texts":["Sulit na sulit, bibili ulit ako"]},'
          '{"author":"PedroLim","texts":["Sulit na sulit, bibili ulit ako"]}],'
          '"body":"ignored when articles exist"}';
      final r = parseGrabbedComments(json, 'Facebook user');
      expect(r.length, 4); // the duplicate is dropped
      expect(r[0].author, 'Maria S.');
      expect(r[0].text, 'Ang bango talaga, tumatagal pa sa damit!');
      expect(r[0].tone, CommentTone.positive);
      expect(r[1].author, 'Juan C.');
      expect(r[2].tone, CommentTone.negative);
      expect(r[3].author, 'PedroLim');
      expect(r[3].tone, CommentTone.positive);
    });

    test('a time and button words glued to a comment are removed', () {
      const json =
          r'{"articles":[{"author":"Maria Santos","texts":["Ang bango talaga!","2hLikeReply"]},{"author":"Juan Dela Cruz","texts":["Legit, dumating agad.","3dLike"]}]}';
      final r = parseGrabbedComments(json, 'Facebook user');
      expect(r.map((e) => e.text).toList(), [
        'Ang bango talaga!',
        'Legit, dumating agad.',
      ]);
    });

    test('with a login box on the page, it still reads comments from the page text', () {
      const json =
          r'{"articles":[],"loginWall":true,"body":"Log In\nOpen app\nVirginia Macaorog and 11 others\nShield Bath Soap updated their cover photo.\n2 Oct\nMaria Santos\nAng bango talaga, tumatagal pa sa damit!\nLike · Reply · 2h\nJuan Dela Cruz\nLegit, dumating agad at sealed ang pack.\n3d"}';
      final r = readGrabbed(json, 'Facebook user');
      expect(r.fromPageText, true);
      expect(r.comments.map((c) => c.author).toList(), ['Maria S.', 'Juan C.']);
      expect(r.comments.first.tone, CommentTone.positive);
      // none of the login junk or the date line became a comment
      expect(
        r.comments.any((c) => c.text.contains('Log') || c.text == '2 Oct'),
        false,
      );
    });

    test('marked comments win over the page text', () {
      const json =
          r'{"articles":[{"author":"Maria Santos","texts":["Ang bango talaga!"]}],"body":"Log In\nSomething else"}';
      final r = readGrabbed(json, 'Facebook user');
      expect(r.fromPageText, false);
      expect(r.comments.single.text, 'Ang bango talaga!');
    });

    test('a page with nothing readable gives no comments', () {
      expect(
        readGrabbed('{"articles":[],"body":"Log In\nOpen app"}', 'x').comments,
        isEmpty,
      );
      expect(readGrabbed('not json', 'x').comments, isEmpty);
    });

    test('when the page gives no comments, nothing is guessed from the page', () {
      const json =
          r'{"articles":[],"loginWall":true,"body":"Log In\nOpen app\nVirginia Macaorog and 11 others\nShield Bath Soap updated their cover photo."}';
      expect(parseGrabbedComments(json, 'Facebook user'), isEmpty);
    });

    test(
      'login-page junk from the screenshot is dropped, real comments stay',
      () {
        const pasted = '''
Log In
Open app
Virginia Macaorog and 11 others
Open Facebook
Log in to connect with them and explore
There's more to see
See what Aiko Daihbi sent
Maria Santos
Ang bango talaga!
Like · Reply · 2h
''';
        final r = parseCopiedComments(pasted, 'Facebook user');
        expect(r.length, 1);
        expect(r.single.author, 'Maria S.');
        expect(r.single.text, 'Ang bango talaga!');
      },
    );

    test('Facebook icon boxes are removed and real comments are kept', () {
      expect(cleanChars(' Ang bango �'), 'Ang bango');
      final r = parseCopiedComments('10 out of 10, sulit!', 'Facebook user');
      expect(r.single.text, '10 out of 10, sulit!');
    });

    test('bad or empty grab results give no comments', () {
      expect(parseGrabbedComments('not json', 'x'), isEmpty);
      expect(parseGrabbedComments('{"articles":[],"body":""}', 'x'), isEmpty);
      expect(
        parseGrabbedComments('{"error":"boom","articles":[]}', 'x'),
        isEmpty,
      );
    });

    test('names are read from Facebook labels', () {
      expect(
        authorFromLabel('Comment by Maria Santos 3 days ago'),
        'Maria Santos',
      );
      expect(authorFromLabel('Reply by Juan 2h'), 'Juan');
      expect(
        authorFromLabel('Comment by Ana Reyes about an hour ago'),
        'Ana Reyes',
      );
      expect(authorFromLabel('Comment by Pedro Lim yesterday'), 'Pedro Lim');
    });
  });

  group('product with photos and proof', () {
    Future<AppStore> open(SharedPreferences prefs) => AppStore.open(
      prefs,
      SellerAccount(phone: '+639171234567', ownerName: 'M', storeName: 'S'),
    );

    test('photos, source, posts and comments survive a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = await open(prefs);
      final p = Product(
        id: newId('p'),
        sku: 'X-1',
        name: 'Soap',
        price: 50,
        stock: 3,
        images: ['/a/1.jpg', 'https://cdn.example.com/2.png'],
        brand: 'Brand',
        sourceUrl: 'https://a2z2go.com/soap.html',
      );
      expect(s.addProduct(p).ok, true);
      p.posts.add(
        SocialPost(
          id: 's1',
          platform: SocialPlatform.facebook,
          url: 'https://facebook.com/x/posts/1',
          title: 'Caption',
          comments: [SharedComment(id: 'c1', author: 'Ana', text: 'Ganda!')],
        ),
      );
      s.updateProduct(p);
      await Future<void>.delayed(Duration.zero);

      final p2 = (await open(prefs)).products.single;
      expect(p2.images, ['/a/1.jpg', 'https://cdn.example.com/2.png']);
      expect(p2.imagePath, '/a/1.jpg');
      expect(p2.brand, 'Brand');
      expect(p2.sourceUrl, 'https://a2z2go.com/soap.html');
      expect(p2.commentCount, 1);
      expect(p2.posts.single.platform, SocialPlatform.facebook);
      expect(p2.posts.single.comments.single.text, 'Ganda!');
    });

    test('products saved before this update still load', () {
      final p = Product.fromJson({
        'id': 'p1',
        'sku': 'OLD',
        'name': 'Old product',
        'price': 10,
        'imagePath': '/old/photo.jpg',
      });
      expect(p.images, ['/old/photo.jpg']);
      expect(p.posts, isEmpty);
      expect(p.brand, '');
    });

    test(
      'sample data includes the Pride listing with its Facebook proof',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final s = await open(prefs);
        expect(s.loadSampleData().ok, true);
        final pride = s.products.firstWhere((e) => e.sku == 'A2G-HH-004');
        expect(pride.price, 215.30);
        expect(pride.brand, 'Pride');
        expect(pride.images.single, startsWith('https://'));
        expect(pride.posts.single.platform, SocialPlatform.facebook);
        // no comments are made up: they only come from a real post
        expect(pride.posts.single.comments, isEmpty);
      },
    );
  });
}
