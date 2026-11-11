import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/screens/products/import_comments_screen.dart';

/// In tests there is no in-app web page, so the screen shows its backup:
/// paste comments, then tick the ones to keep.
void main() {
  testWidgets('backup paste: positive ones ticked, Add counts what is shown', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    final post = SocialPost(
      id: 's1',
      platform: SocialPlatform.facebook,
      url: 'https://www.facebook.com/x/posts/1',
    );
    var changed = 0;

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
                    builder: (_) => ImportCommentsScreen(
                      post: post,
                      onChanged: () => changed++,
                    ),
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

    // No paste box up front: the screen starts with the backup choices.
    expect(find.text('Paste comments instead'), findsOneWidget);
    expect(find.text('Open in Facebook'), findsOneWidget);
    expect(find.text('Copy debug info'), findsOneWidget);

    await t.tap(find.text('Paste comments instead'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      'Maria Santos\nAng bango talaga, tumatagal pa sa damit!\nLike · Reply · 2h\n'
      'Juan Dela Cruz\nLegit, dumating agad at sealed ang pack.\n3d\n'
      'Ana Reyes\nPangit, sira agad\n5h\n'
      'Pedro Lim\npa-follow po https://spam.example.com\n1w',
    );
    await t.tap(find.text('Find comments'));
    await t.pumpAndSettle();

    expect(find.textContaining('Found 4'), findsOneWidget);
    expect(find.text('Add 2 comments'), findsOneWidget);

    // With "Show positive only", Add counts what is on screen: still 2.
    await t.tap(find.text('Show positive only'));
    await t.pumpAndSettle();
    expect(find.text('Add 2 comments'), findsOneWidget);
    expect(find.text('Ana R.'), findsNothing);

    // Select all while filtered only selects what is shown.
    await t.tap(find.text('Select all'));
    await t.pumpAndSettle();
    expect(find.text('Add 2 comments'), findsOneWidget);

    await t.tap(find.text('Add 2 comments'));
    await t.pumpAndSettle();

    expect(changed, 1);
    expect(post.comments.map((c) => c.author).toList(), [
      'Maria S.',
      'Juan C.',
    ]);
    expect(find.text('open'), findsOneWidget);
  });
}
