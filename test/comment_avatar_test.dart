import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/widgets/social.dart';

void main() {
  Future<void> show(WidgetTester t, String name) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: CommentAvatar(name))));

  testWidgets('the avatar shows a whole letter, even a fancy one', (t) async {
    await show(t, 'maryann');
    expect(find.text('M'), findsOneWidget);
    await show(t, '𝓑atang');
    expect(find.text('𝓑'), findsOneWidget); // not half of it
  });

  testWidgets('emoji first: use the first letter; no letters: a person icon', (
    t,
  ) async {
    await show(t, '❤️❤️Tella');
    expect(find.text('T'), findsOneWidget);
    await show(t, '🪼🪼');
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
