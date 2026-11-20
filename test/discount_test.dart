import 'package:flutter_test/flutter_test.dart';

import 'package:a2z2go_seller/data/models.dart';

void main() {
  test('discount percent comes from the old price and survives saving', () {
    final p = Product(
      id: 'p',
      sku: 'S',
      name: 'Soap',
      price: 18.4,
      oldPrice: 36.8,
    );
    expect(p.discountPercent, 50);

    final back = Product.fromJson(p.toJson());
    expect(back.oldPrice, 36.8);
    expect(back.discountPercent, 50);
  });

  test('no old price, or one that is not higher, means no discount', () {
    expect(Product(id: 'a', sku: 'A', name: 'A', price: 10).discountPercent, 0);
    expect(
      Product(
        id: 'b',
        sku: 'B',
        name: 'B',
        price: 10,
        oldPrice: 10,
      ).discountPercent,
      0,
    );
    // Older saves have no oldPrice at all.
    final old = Product.fromJson({'id': 'c', 'name': 'C', 'price': 5});
    expect(old.oldPrice, 0);
    expect(old.discountPercent, 0);
  });
}
