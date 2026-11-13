import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/models.dart';
import 'package:a2z2go_seller/screens/buyer/share_sheet.dart';

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
}
