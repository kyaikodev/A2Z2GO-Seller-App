import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/sample_data.dart';

void main() {
  test(
    'every sample product has a small bundled photo and a real page link',
    () {
      expect(sampleProducts.length, 20);
      for (final p in sampleProducts) {
        expect(
          p.images.single,
          startsWith('asset:assets/sample/'),
          reason: p.sku,
        );
        final file = File(p.images.single.substring('asset:'.length));
        expect(
          file.existsSync(),
          true,
          reason: '${p.sku}: photo file is missing',
        );
        expect(
          file.lengthSync(),
          lessThan(200 * 1024),
          reason: '${p.sku}: photo is too big for the app',
        );
        expect(p.sourceUrl, startsWith('https://a2z2go.com/'), reason: p.sku);
        expect(p.price, greaterThan(0), reason: p.sku);
        expect(p.cost, lessThan(p.price), reason: p.sku);
      }
    },
  );

  test(
    'the sample photos are listed in pubspec.yaml so they ship in the app',
    () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/sample/'),
      );
    },
  );
}
