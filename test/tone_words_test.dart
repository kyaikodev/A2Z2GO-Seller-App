import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/comment_tools.dart';

void main() {
  test('Tagalog "ma-" forms and common praise words count as positive', () {
    CommentTone t(String s) => classifyComment(s);
    expect(t('napaka refeshing gamitin mabango pa'), CommentTone.positive);
    expect(t('Mabango at mabilis dumating'), CommentTone.positive);
    expect(t('anti bacterial and affordable'), CommentTone.positive);
    expect(t('maganda talaga smooth'), CommentTone.positive);
  });

  test('neutral and negative comments are not pulled upward', () {
    CommentTone t(String s) => classifyComment(s);
    expect(t('still use it'), CommentTone.neutral);
    expect(t('Hindi mabango'), CommentTone.negative); // negated
    expect(t('Malate branch ba ito?'), CommentTone.neutral); // not "late"
  });
}
