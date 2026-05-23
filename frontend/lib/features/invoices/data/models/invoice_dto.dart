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
    taxableValue: _toDouble(json['taxableValue']),
    igstAmount: _toDouble(json['igstAmount']),
    cgstAmount: _toDouble(json['cgstAmount']),
    sgstAmount: _toDouble(json['sgstAmount']),
    cessRate: _toDouble(json['cessRate']),
    cessAmount: _toDouble(json['cessAmount']),
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
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return Invoice(
      id: json['id'] as int,
      invoiceNo: json['invoiceNo'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      vendor: _vendorFromJson(json['vendor'] as Map<String, dynamic>?),
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerGstin: json['customerGstin'] as String?,
      customerAddress: json['customerAddress'] as String?,
      customerCity: json['customerCity'] as String?,
      customerState: json['customerState'] as String?,
      customerStateCode: json['customerStateCode'] as String?,
      customerPinCode: json['customerPinCode'] as String?,
      customerPanNumber: json['customerPanNumber'] as String?,
      vendorName: json['vendorName'] as String?,
      vendorPhone: json['vendorPhone'] as String?,
      vendorGstin: json['vendorGstin'] as String?,
      vendorAddress: json['vendorAddress'] as String?,
      vendorCity: json['vendorCity'] as String?,
      vendorState: json['vendorState'] as String?,
      vendorStateCode: json['vendorStateCode'] as String?,
      vendorPinCode: json['vendorPinCode'] as String?,
      vendorPanNumber: json['vendorPanNumber'] as String?,
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['taxAmount']),
      discount: _toDouble(json['discount']),
      total: _toDouble(json['total']),
      taxableValue: _toDouble(json['taxableValue']),
      igstAmount: _toDouble(json['igstAmount']),
      cgstAmount: _toDouble(json['cgstAmount']),
      sgstAmount: _toDouble(json['sgstAmount']),
      cessAmount: _toDouble(json['cessAmount']),
      roundOff: _toDouble(json['roundOff']),
      amountInWords: json['amountInWords'] as String?,
      documentType: (json['documentType'] as String?) ?? 'TAX_INVOICE',
      financialYear: (json['financialYear'] as String?) ?? '',
      placeOfSupplyStateCode: json['placeOfSupplyStateCode'] as String?,
      isInterstate: (json['isInterstate'] as bool?) ?? false,
      note: json['note'] as String?,
      invoiceDate: DateTime.parse(json['invoiceDate'] as String),
      createdAt: createdAt,
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'] as String)
          : createdAt,
      items:
          itemsJson
              ?.map((e) => _itemFromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemCount: count?['items'] as int?,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, dynamic> toCreateJson({
    required String type,
    int? vendorId,
    int? partyId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    String? documentType,
    String? placeOfSupplyStateCode,
    required List<Map<String, dynamic>> items,
  }) {
    final payload = <String, dynamic>{'type': type, 'items': items};
    if (vendorId != null) payload['vendorId'] = vendorId;
    if (partyId != null) payload['partyId'] = partyId;
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
    if (documentType != null && documentType.isNotEmpty) {
      payload['documentType'] = documentType;
    }
    if (placeOfSupplyStateCode != null && placeOfSupplyStateCode.isNotEmpty) {
      payload['placeOfSupplyStateCode'] = placeOfSupplyStateCode;
    }
    return payload;
  }
}
