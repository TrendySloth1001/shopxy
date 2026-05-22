import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_providers.dart';

void main() {
  group('ShopInvoiceDetail totals', () {
    test('total = subtotal + tax - discount', () {
      final inv = fakeInvoiceDetail(subtotal: 1000, tax: 100, discount: 50);
      expect(inv.total, 1050);
    });

    test('zero discount still totals correctly', () {
      final inv = fakeInvoiceDetail(subtotal: 800, tax: 80, discount: 0);
      expect(inv.total, 880);
    });

    test('item total matches its qty × unitPrice', () {
      final inv = fakeInvoiceDetail();
      final item = inv.items.single;
      expect(item.total, item.quantity * item.unitPrice);
    });
  });
}
