import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/data/sample_data.dart';
import 'package:a2z2go_seller/screens/buyer/share_sheet.dart';
import 'package:a2z2go_seller/share_web.dart' show skuFromLink;

void main() {
  test('a product listed on the website shares that real page', () {
    final p = Product(
      id: 'p1',
      sku: 'A2G-1',
      name: 'Festive Feast',
      price: 445,
      sourceUrl: 'https://a2z2go.com/festive-feast.html',
    );
    expect(shareLink(p), 'https://a2z2go.com/festive-feast.html');
    expect(hasRealLink(p), true);
    final text = shareMessage(p);
    expect(text, contains('Festive Feast'));
    expect(text, contains('₱445'));
    expect(text, contains('https://a2z2go.com/festive-feast.html'));
  });

  test('a product without a page uses its own id, never the SKU', () {
    final p = Product(id: 'p-abc', sku: 'SKU-0001', name: 'Soap', price: 99.5);
    expect(shareLink(p), 'https://a2z2go.com/p/p-abc');
    expect(shareLink(p).contains('SKU'), false);
    expect(hasRealLink(p), false);
    expect(shareMessage(p), contains('₱99.50'));
  });

  Product sampleCopy({String? sourceUrl}) {
    final s = sampleProducts.first; // A2G-FD-001, which has a website page
    return Product(
      id: 'p-sample',
      sku: s.sku,
      name: s.name,
      price: s.price,
      sourceUrl: sourceUrl ?? s.sourceUrl,
    );
  }

  test(
    'a sample product shares the sample page, so the QR works on any phone',
    () {
      final p = sampleCopy();
      expect(isSample(p), true);
      expect(
        shareLink(p),
        'https://kyaikodev.github.io/A2Z2GO-Seller-App/#/product/A2G-FD-001',
      );
      expect(hasRealLink(p), true);
      expect(shareMessage(p), contains(shareLink(p)));
    },
  );

  test('every sample product has a link the sample page can read back', () {
    for (final s in sampleProducts) {
      final p = Product(
        id: 'p-${s.sku}',
        sku: s.sku,
        name: s.name,
        price: s.price,
        sourceUrl: s.sourceUrl,
      );
      expect(isSample(p), true, reason: s.sku);
      expect(skuFromLink(Uri.parse(shareLink(p)).fragment), s.sku);
    }
  });

  test('a seller\'s own products are not treated as samples', () {
    // Same SKU as a sample, but a different website link: the seller's own.
    final changed = sampleCopy(
      sourceUrl: 'https://a2z2go.com/my-own-page.html',
    );
    expect(isSample(changed), false);
    expect(shareLink(changed), 'https://a2z2go.com/my-own-page.html');

    // Same SKU, no website page at all: still the seller's own.
    final own = sampleCopy(sourceUrl: '');
    expect(isSample(own), false);
    expect(shareLink(own), 'https://a2z2go.com/p/p-sample');
    expect(hasRealLink(own), false);
  });
}
