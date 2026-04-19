import 'package:shopxy/features/invoices/domain/entities/invoice.dart';

class InvoiceDto {
  static InvoiceItem _itemFromJson(Map<String, dynamic> json) => InvoiceItem(
    id: json['id'] as int,
    invoiceId: json['invoiceId'] as int,
    productId: json['productId'] as int,
    productName: json['productName'] as String,
    productSku: json['productSku'] as String,
    hsn: json['hsn'] as String?,
    unit: json['unit'] as String? ?? 'PCS',
    quantity: _toDouble(json['quantity']),
    unitPrice: _toDouble(json['unitPrice']),
    taxPercent: _toDouble(json['taxPercent']),
    discount: _toDouble(json['discount']),
    total: _toDouble(json['total']),
  );

  static InvoiceVendorRef? _vendorFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return InvoiceVendorRef(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  static Invoice fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;
    return Invoice(
      id: json['id'] as int,
      invoiceNo: json['invoiceNo'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      vendor: _vendorFromJson(json['vendor'] as Map<String, dynamic>?),
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerGstin: json['customerGstin'] as String?,
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['taxAmount']),
      discount: _toDouble(json['discount']),
      total: _toDouble(json['total']),
      note: json['note'] as String?,
      invoiceDate: DateTime.parse(json['invoiceDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      items:
          itemsJson
              ?.map((e) => _itemFromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemCount: count?['items'] as int?,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, dynamic> toCreateJson({
    required String type,
    int? vendorId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    required List<Map<String, dynamic>> items,
  }) {
    final payload = <String, dynamic>{'type': type, 'items': items};
    if (vendorId != null) payload['vendorId'] = vendorId;
    if (customerName != null && customerName.isNotEmpty) {
      payload['customerName'] = customerName;
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      payload['customerPhone'] = customerPhone;
    }
    if (customerGstin != null && customerGstin.isNotEmpty) {
      payload['customerGstin'] = customerGstin;
    }
    if (discount != null && discount > 0) payload['discount'] = discount;
    if (note != null && note.isNotEmpty) payload['note'] = note;
    return payload;
  }
}
