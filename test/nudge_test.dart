import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/widgets/product_page.dart';

import 'comments_link_test.dart' show open, post;
import 'test_fonts.dart';

final _posts = [
  post('tt', SocialPlatform.tiktok, 4),
  post('fb', SocialPlatform.facebook, 2),
];

double _barTop(WidgetTester t) => t.getTopLeft(find.byType(CommentsPeek)).dy;
double _cartLeft(WidgetTester t) => t.getCenter(find.text('Add To Cart')).dx;

/// Lets time pass the way a phone does: many small frames, not one big jump
/// (a big jump starts an animation but never gives it frames to finish).
Future<void> elapse(WidgetTester t, int milliseconds) async {
  for (var left = milliseconds; left > 0; left -= 100) {
    await t.pump(Duration(milliseconds: left < 100 ? left : 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  test('the lock lets only one nudge move at a time', () {
    final lock = NudgeLock();
    expect(lock.tryStart(), isTrue);
    expect(lock.tryStart(), isFalse, reason: 'the other one is moving');
    lock.end();
    expect(lock.tryStart(), isTrue);
  });

  testWidgets('the comments bar hops up every 9 seconds, then settles', (
    t,
  ) async {
    await open(t, _posts);
    final rest = _barTop(t);

    await elapse(t, 8000);
    expect(_barTop(t), rest, reason: 'nothing before the 9 seconds');

    await elapse(t, 600); // the timer fires (open() already used 0.4 s)
    await t.pump(const Duration(milliseconds: 16)); // the animation starts
    await t.pump(const Duration(milliseconds: 250)); // about the top of the hop
    expect(_barTop(t), lessThan(rest - 3), reason: 'it hops up');
    expect(_barTop(t), greaterThan(rest - 7), reason: 'but only a little');

    await t.pump(const Duration(milliseconds: 1000));
    expect(_barTop(t), closeTo(rest, 0.01), reason: 'and is back at rest');
  });

  testWidgets('Add To Cart wiggles every 13 seconds, a little', (t) async {
    await open(t, _posts);
    final rest = _cartLeft(t);

    await elapse(t, 12000);
    expect(_cartLeft(t), closeTo(rest, 0.01), reason: 'not before 13 seconds');

    await elapse(t, 600); // the timer fires (open() already used 0.4 s)
    var most = 0.0;
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 40));
      final shift = (_cartLeft(t) - rest).abs();
      if (shift > most) most = shift;
    }
    expect(most, greaterThan(1.0), reason: 'it moves');
    expect(most, lessThanOrEqualTo(3.01), reason: 'but never more than 3 px');

    await t.pump(const Duration(seconds: 1));
    expect(_cartLeft(t), closeTo(rest, 0.01), reason: 'and is back at rest');
  });

  testWidgets('with reduced motion on, nothing moves', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(t, _posts);
    final bar = _barTop(t);
    final cart = _cartLeft(t);
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 1000));
      expect(_barTop(t), bar);
      expect(_cartLeft(t), cart);
    }
  });

  testWidgets('a finger on the bar stops its hop', (t) async {
    await open(t, _posts);
    final rest = _barTop(t);
    final g = await t.startGesture(t.getCenter(find.byType(CommentsPeek)));
    await t.pump(const Duration(seconds: 9));
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 250));
    expect(_barTop(t), rest);
    await g.cancel();
  });

  testWidgets('two nudges with the same lock never move together', (t) async {
    final lock = NudgeLock();
    Widget box(Key k) => Nudge(
      kind: NudgeKind.hop,
      every: const Duration(seconds: 2),
      amount: 6,
      length: const Duration(milliseconds: 500),
      lock: lock,
      child: SizedBox(key: k, width: 40, height: 40),
    );
    const a = Key('a');
    const b = Key('b');
    await t.pumpWidget(MaterialApp(home: Column(children: [box(a), box(b)])));
    final restA = t.getTopLeft(find.byKey(a)).dy;
    final restB = t.getTopLeft(find.byKey(b)).dy;
    await t.pump(const Duration(seconds: 2)); // both timers fire together
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 250));
    final movedA = t.getTopLeft(find.byKey(a)).dy != restA;
    final movedB = t.getTopLeft(find.byKey(b)).dy != restB;
    expect(movedA != movedB, isTrue, reason: 'exactly one of the two moves');
  });
}
