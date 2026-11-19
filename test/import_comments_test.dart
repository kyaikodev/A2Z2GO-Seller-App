import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/screens/products/import_comments_screen.dart';

/// In tests there is no in-app web page, so the screen shows its backup:
/// add the comments yourself, then tick the ones to keep.
Future<void> openScreen(
  WidgetTester t,
  SocialPost post,
  VoidCallback onChanged,
) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      ImportCommentsScreen(post: post, onChanged: onChanged),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

SocialPost _post(SocialPlatform p, String url) =>
    SocialPost(id: 's1', platform: p, url: url);

void main() {
  testWidgets('add comments yourself one by one, then keep them', (t) async {
    final post = _post(
      SocialPlatform.facebook,
      'https://www.facebook.com/x/posts/1',
    );
    var changed = 0;
    await openScreen(t, post, () => changed++);

    // Plain screen: no technical buttons for the seller.
    expect(find.text('Add comments yourself'), findsOneWidget);
    expect(find.text('Open in Facebook'), findsOneWidget);
    expect(find.text('Copy debug info'), findsNothing);
    expect(find.text('Paste comments instead'), findsNothing);

    await t.tap(find.text('Add comments yourself'));
    await t.pumpAndSettle();

    // First comment: with a name.
    await t.enterText(find.widgetWithText(TextField, 'Name *'), 'Maria Santos');
    await t.enterText(
      find.widgetWithText(TextField, 'Comment *'),
      'Pangit, sira agad',
    );
    await t.tap(find.text('Add this comment'));
    await t.pumpAndSettle();
    expect(find.text('Added so far (1)'), findsOneWidget);
    expect(find.text('Maria S.'), findsOneWidget);

    // A comment without a name is refused, in red under the name box.
    await t.enterText(
      find.widgetWithText(TextField, 'Comment *'),
      'Ang bango talaga, sulit!',
    );
    await t.tap(find.text('Add this comment'));
    await t.pumpAndSettle();
    expect(find.text('Type the name first.'), findsOneWidget);
    expect(find.text('Added so far (1)'), findsOneWidget);

    // With a name it goes in.
    await t.enterText(
      find.widgetWithText(TextField, 'Name *'),
      'Juan Dela Cruz',
    );
    await t.tap(find.text('Add this comment'));
    await t.pumpAndSettle();
    expect(find.text('Added so far (2)'), findsOneWidget);
    expect(find.text('Juan C.'), findsOneWidget);

    // Neither a name nor a comment: both are asked for.
    await t.tap(find.text('Add this comment'));
    await t.pumpAndSettle();
    expect(find.text('Type the name first.'), findsOneWidget);
    expect(find.text('Type the comment first.'), findsOneWidget);

    await t.tap(find.text('Done (2 comments)'));
    await t.pumpAndSettle();

    // What the seller typed is all ticked.
    expect(find.textContaining('Found 2'), findsOneWidget);
    expect(find.text('Add 2 comments'), findsOneWidget);

    // "Positive first" puts the nice comment on top.
    double top(String s) => t.getTopLeft(find.text(s)).dy;
    expect(top('Pangit, sira agad') < top('Ang bango talaga, sulit!'), isTrue);
    await t.tap(find.text('Positive first'));
    await t.pumpAndSettle();
    expect(top('Ang bango talaga, sulit!') < top('Pangit, sira agad'), isTrue);

    await t.tap(find.text('Add 2 comments'));
    await t.pumpAndSettle();
    expect(changed, 1);
    expect(post.comments.map((c) => c.author).toSet(), {'Maria S.', 'Juan C.'});
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('paste many at once splits names and comments', (t) async {
    final post = _post(
      SocialPlatform.facebook,
      'https://www.facebook.com/x/posts/1',
    );
    await openScreen(t, post, () {});
    await t.tap(find.text('Add comments yourself'));
    await t.pumpAndSettle();

    await t.tap(find.text('Paste many at once'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      'Maria Santos\nAng bango talaga, tumatagal pa sa damit!\nLike · Reply · 2h\n'
      'Juan Dela Cruz\nLegit, dumating agad at sealed ang pack.\n3d',
    );
    await t.tap(find.text('Add these to the list'));
    await t.pumpAndSettle();

    // back on the one-at-a-time form, with both in the list
    expect(find.text('Added so far (2)'), findsOneWidget);
    expect(find.text('Maria S.'), findsOneWidget);
    expect(find.text('Juan C.'), findsOneWidget);
  });

  testWidgets('a site the reader does not know says so, in plain words', (
    t,
  ) async {
    final post = _post(SocialPlatform.shopee, 'https://shopee.ph/product/1/2');
    await openScreen(t, post, () {});

    expect(
      find.text(
        "We can't read comments from this site yet. Add them yourself instead.",
      ),
      findsOneWidget,
    );
    expect(find.text('Add comments yourself'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('More details'), findsNothing);
    expect(find.textContaining('page text'), findsNothing);
  });
}
