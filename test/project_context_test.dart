import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the project notes honest: every version in `pubspec.yaml` must be
/// written in `PROJECT_CONTEXT.md` (in the change log or the session log), so
/// a build or a commit without notes fails here.
void main() {
  test('PROJECT_CONTEXT.md mentions the current app version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    final notes = File('PROJECT_CONTEXT.md').readAsStringSync();
    expect(
      notes.contains(version),
      isTrue,
      reason:
          'Write version $version in PROJECT_CONTEXT.md (session log and '
          'change log) before committing.',
    );
  });

  test('the session log section exists', () {
    final notes = File('PROJECT_CONTEXT.md').readAsStringSync();
    expect(notes, contains('### Session log'));
  });
}
