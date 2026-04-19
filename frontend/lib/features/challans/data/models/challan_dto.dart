import 'package:shopxy/features/challans/domain/entities/challan.dart';

class ChallanDto {
  static ChallanItem _itemFromJson(Map<String, dynamic> j) => ChallanItem(
        id: j['id'] as int,
        challanId: j['challanId'] as int,
        productId: j['productId'] as int,
        productName: j['productName'] as String,
        productSku: j['productSku'] as String,
        unit: j['unit'] as String? ?? 'PCS',
        quantity: (j['quantity'] as num).toDouble(),
      );

  static ChallanInvoiceRef? _invoiceRefFromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return ChallanInvoiceRef(
      id: j['id'] as int,
      invoiceNo: j['invoiceNo'] as String,
      status: j['status'] as String,
    );
  }

  static Challan fromJson(Map<String, dynamic> j) {
    final itemsList = j['items'] as List<dynamic>?;
    final count = (j['_count'] as Map<String, dynamic>?)?['items'] as int?;
    return Challan(
      id: j['id'] as int,
      challanNo: j['challanNo'] as String,
      status: j['status'] as String,
      partyName: j['partyName'] as String,
      partyPhone: j['partyPhone'] as String?,
      note: j['note'] as String?,
      invoiceId: j['invoiceId'] as int?,
      invoice: _invoiceRefFromJson(j['invoice'] as Map<String, dynamic>?),
      items: itemsList?.map((e) => _itemFromJson(e as Map<String, dynamic>)).toList() ?? [],
      itemCount: count ?? itemsList?.length ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String partyName,
    String? partyPhone,
    String? note,
    required List<ChallanItemDraft> items,
  }) =>
      {
        'partyName': partyName,
        if (partyPhone != null && partyPhone.isNotEmpty) 'partyPhone': partyPhone,
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'quantity': i.quantity,
                })
            .toList(),
      };

  static Map<String, dynamic> toConvertJson({
    String? customerName,
    String? customerGstin,
    double? discount,
    String? note,
  }) =>
      {
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        if (customerGstin != null && customerGstin.isNotEmpty) 'customerGstin': customerGstin,
        if (discount != null && discount > 0) 'discount': discount,
        if (note != null && note.isNotEmpty) 'note': note,
      };
}
