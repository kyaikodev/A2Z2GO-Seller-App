import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/core/theme.dart';
import 'package:a2z2go_seller/widgets/pick_field.dart';

Future<TextEditingController> _show(
  WidgetTester t, {
  required bool required,
  List<String> options = const ['Household', 'Beauty'],
  GlobalKey<FormFieldState<String>>? key,
  GlobalKey<FormState>? form,
}) async {
  final c = TextEditingController();
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Form(
          key: form,
          child: PickOrAddField(
            fieldKey: key,
            controller: c,
            label: 'Category',
            noun: 'category',
            required: required,
            options: options,
          ),
        ),
      ),
    ),
  );
  return c;
}

void main() {
  testWidgets('pick one that exists', (t) async {
    final c = await _show(t, required: true);
    await t.tap(find.byType(TextFormField));
    await t.pumpAndSettle();
    expect(find.text('Choose a category'), findsOneWidget);
    await t.tap(find.text('Beauty'));
    await t.pumpAndSettle();
    expect(c.text, 'Beauty');
  });

  testWidgets('type a new one and add it', (t) async {
    final c = await _show(t, required: true);
    await t.tap(find.byType(TextFormField));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Pet Care');
    await t.pumpAndSettle();
    // nothing matches, so the only choice is to add it
    expect(find.text('Household'), findsNothing);
    await t.tap(find.text('Add "Pet Care"'));
    await t.pumpAndSettle();
    expect(c.text, 'Pet Care');
  });

  testWidgets('a required field that is empty says so, in red', (t) async {
    final form = GlobalKey<FormState>();
    final key = GlobalKey<FormFieldState<String>>();
    await _show(t, required: true, key: key, form: form);
    expect(
      find.text('Category *'),
      findsOneWidget,
    ); // the label, with its red star
    expect(form.currentState!.validate(), isFalse);
    await t.pump();
    expect(find.text('Pick a category, or add a new one.'), findsOneWidget);
    expect(scrollToFirstError([key]), isTrue);
  });

  testWidgets('an optional field can be cleared', (t) async {
    final c = await _show(t, required: false);
    expect(find.text('Category (optional)'), findsOneWidget);
    await t.tap(find.byType(TextFormField));
    await t.pumpAndSettle();
    await t.tap(find.text('Household'));
    await t.pumpAndSettle();
    expect(c.text, 'Household');
    await t.tap(find.byType(TextFormField));
    await t.pumpAndSettle();
    await t.tap(find.text('Clear'));
    await t.pumpAndSettle();
    expect(c.text, '');
  });
}
