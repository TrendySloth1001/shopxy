import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

void main() {
  group('OrderInvoiceRef.supportsInputCredit', () {
    OrderInvoiceRef parse(Map<String, dynamic> extra) => OrderInvoiceRef.fromJson({
      'id': '1',
      'invoiceNo': 'INV/26-27/00001',
      'total': 1180,
      'status': 'CONFIRMED',
      ...extra,
    })!;

    test('a tax invoice carrying the buyer GSTIN is claimable', () {
      final invoice = parse({
        'documentType': 'TAX_INVOICE',
        'customerGstin': '19AAACI1681G1ZM',
      });
      expect(invoice.supportsInputCredit, isTrue);
      expect(invoice.customerGstin, '19AAACI1681G1ZM');
    });

    test('a tax invoice with no recipient GSTIN is a B2C sale', () {
      final invoice = parse({
        'documentType': 'TAX_INVOICE',
        'customerGstin': null,
      });
      expect(invoice.supportsInputCredit, isFalse);
    });

    test('a bill of supply is never claimable, GSTIN or not', () {
      final invoice = parse({
        'documentType': 'BILL_OF_SUPPLY',
        'customerGstin': '19AAACI1681G1ZM',
      });
      expect(invoice.supportsInputCredit, isFalse);
    });

    test('an older payload without documentType is not treated as claimable', () {
      final invoice = parse({});
      expect(invoice.supportsInputCredit, isFalse);
    });
  });
}
