import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's own font (Work Sans) so tests measure text the way a phone
/// does. Without it, tests fall back to a very wide placeholder font.
Future<void> loadAppFonts() async {
  final loader = FontLoader('WorkSans');
  for (final w in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    final f = File('assets/fonts/WorkSans-$w.ttf');
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}
