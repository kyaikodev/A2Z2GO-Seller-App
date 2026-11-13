import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/screens/products/grab_script.dart';

/// A typo inside the page script (a lost backslash once) stops it from running
/// on every site, and no other test notices. Ask Node to check the syntax.
void main() {
  test('the reader scripts are valid JavaScript', () async {
    final probe = await Process.run('node', [
      '--version',
    ]).catchError((_) => ProcessResult(0, 1, '', ''));
    if (probe.exitCode != 0) {
      markTestSkipped('Node is not installed');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('a2z_js');
    try {
      for (final entry in {'grab': grabScript, 'debug': debugScript}.entries) {
        final file = File('${dir.path}/${entry.key}.js')
          ..writeAsStringSync('(function(){${entry.value}\n});');
        final r = await Process.run('node', ['--check', file.path]);
        expect(r.exitCode, 0, reason: '${entry.key}: ${r.stderr}');
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
