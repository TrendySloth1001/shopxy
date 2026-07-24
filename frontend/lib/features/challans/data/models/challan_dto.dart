import 'package:shopxy/features/challans/domain/entities/challan.dart';

class ChallanDto {
  /// Prisma's `Decimal` columns serialize as JSON strings (e.g. "3.000"),
  /// not numbers — casting them straight to `num` throws at runtime.
  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static ChallanItem _itemFromJson(Map<String, dynamic> j) => ChallanItem(
        id: j['id'].toString(),
        challanId: j['challanId'].toString(),
        productId: j['productId'].toString(),
        productName: j['productName'] as String,
        productSku: j['productSku'] as String,
        unit: j['unit'] as String? ?? 'PCS',
        quantity: _asDouble(j['quantity']),
      );

  static ChallanInvoiceRef? _invoiceRefFromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return ChallanInvoiceRef(
      id: j['id'].toString(),
      invoiceNo: j['invoiceNo'] as String,
      status: j['status'] as String,
    );
  }

  static Challan fromJson(Map<String, dynamic> j) {
    final itemsList = j['items'] as List<dynamic>?;
    final count = (j['_count'] as Map<String, dynamic>?)?['items'] as int?;
    return Challan(
      id: j['id'].toString(),
      challanNo: j['challanNo'] as String,
      status: j['status'] as String,
      partyId: j['partyId']?.toString(),
      partyName: j['partyName'] as String,
      partyPhone: j['partyPhone'] as String?,
      note: j['note'] as String?,
      invoiceId: j['invoiceId']?.toString(),
      invoice: _invoiceRefFromJson(j['invoice'] as Map<String, dynamic>?),
      items: itemsList?.map((e) => _itemFromJson(e as Map<String, dynamic>)).toList() ?? [],
      itemCount: count ?? itemsList?.length ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  static Map<String, dynamic> toCreateJson({
    String? partyId,
    String? partyName,
    String? partyPhone,
    String? note,
    required List<ChallanItemDraft> items,
  }) =>
      {
        'partyId': ?partyId,
        if (partyName != null && partyName.isNotEmpty) 'partyName': partyName,
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
