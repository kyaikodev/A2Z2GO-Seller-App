import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/comment_tools.dart';

/// The page text of a real Facebook post (Shield Bath Soap), copied from the
/// app's "Copy debug info". The post has exactly 3 comments. After them,
/// Facebook adds related pages and other posts, which are not comments.
const _realBody = '''
Facebook
Log In
Open app
Shield Bath Soap
28 Jul ·
Basta langga ni Wilbert Ross, ibang level talaga ang freshness 🩵

Thank you to all who joined & won our Langga Dance Challenge with Shield 💃🏻

We also hope that you enjoyed our roving cam game and of... See more
+27
46
3
9
Maricar Besid
 ·
3mo
Thank you Shield Bath Soap💙💙💙
Reply
Johannah Marrie Lubay
 ·
3mo
Thank you, Shield! 💗
Reply
Wi Ngi
 ·
3mo
Thank you so much, Shield 🫶🏻
Reply
Related Pages
Pride
564.9K likes
Follow
Unique Toothpaste
455.2K likes
Follow
Message mo ako para sa pag CLAIM Ngayon
20.7K likes
Follow
Silka
1.4M likes
Follow
Go Rewards
1.3M likes
Follow
Recent posts
Shield Bath Soap
1d ·
Ang fre-fresh naman ng mga characters sa "Love, Siargao" ng Viu 🙌🏻 Kaya naman pala eh... naka Shield Bath Soap 💯

Good series recommendation, DJ Faith! Tara, panoorin na rin natin 🤗

#ShieldBathSoap... See more
1
Shield Bath Soap
3d ·
Kahit kami mapapa-binge watch sa "Love, Siargao" sa Viu eh 🤭 Lalo na 'pag may fresh & cool scenes nila Han Bin at Quinto... 😉 Syempre, this is brought to us by Shield Bath Soap!

#ShieldBathSoap... See more
5
2
Rosemarie Bromacom
.
Reply
Shield Bath Soap
15 Oct ·
"Basta para sa isla!" 🏝️💚 Catch Ariel spreading the love and Stronger Together with Shield Soap: Official Protector of the Mangroves, we're catching waves and shielding our island's mangroves. join... See more
392
3
3
Jun Acasio
Unsay kataw anan.???
Reply
Shield Bath Soap
7 Oct ·
With #ShieldBathSoap, you can emb''';

void main() {
  test('the real Facebook post gives exactly its 3 comments, with names', () {
    final json = jsonEncode({
      'articles': <Object>[],
      'loginWall': false,
      'names': [
        'Maricar Besid',
        'Johannah Marrie Lubay',
        'Wi Ngi',
        'Rosemarie Bromacom',
        'Jun Acasio',
      ],
      'body': _realBody,
    });
    final r = readGrabbed(json, 'Facebook user');

    expect(r.fromPageText, false);
    expect(r.comments.map((c) => c.author).toList(), [
      'Maricar B.',
      'Johannah L.',
      'Wi N.',
    ]);
    expect(r.comments.map((c) => c.text).toList(), [
      'Thank you Shield Bath Soap💙💙💙',
      'Thank you, Shield! 💗',
      'Thank you so much, Shield 🫶🏻',
    ]);
    // nothing from the other posts, related pages or the page's own captions
    final all = r.comments.map((c) => '${c.author} ${c.text}').join(' ');
    expect(all.contains('Jun'), false);
    expect(all.contains('Rosemarie'), false);
    expect(all.contains('Langga'), false);
    expect(all.contains('Pride'), false);
  });

  test('without names it still reads the page text, marked as a guess', () {
    final json = jsonEncode({
      'articles': <Object>[],
      'names': <String>[],
      'body': _realBody,
    });
    final r = readGrabbed(json, 'Facebook user');
    expect(r.fromPageText, true);
    expect(r.comments, isNotEmpty);
  });

  test('a name with no reply line is not turned into a comment', () {
    final r = commentsByName('Maria Santos\nSome text without any reply', [
      'Maria Santos',
    ]);
    expect(r, isEmpty);
  });
}
