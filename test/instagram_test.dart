import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/comment_tools.dart';

void main() {
  test('Instagram comments read from the page are kept as they are', () {
    const json =
        r'{"articles":[{"author":"kapitankikoy","texts":["Watch out for Clickers, Sir."]},{"author":"coveredmum","texts":["How do you just sit in that edge just like that"]}],"names":[],"body":"x","host":"www.instagram.com"}';
    final r = readGrabbed(json, 'Instagram user');
    expect(r.fromPageText, false);
    expect(r.comments.map((c) => c.author).toList(), [
      'kapitankikoy',
      'coveredmum',
    ]);
  });

  test('Instagram page text is never turned into comments', () {
    const json =
        r'{"articles":[],"names":[],"body":"Log In Sign Up Never miss a post View all 7,455 comments More posts from instagram","host":"www.instagram.com"}';
    expect(readGrabbed(json, 'Instagram user').comments, isEmpty);
  });
}
