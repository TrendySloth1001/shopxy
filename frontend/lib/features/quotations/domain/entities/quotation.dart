/// One line in a quotation — a product the merchant added to the bucket.
class QuotationLine {
  const QuotationLine({
    required this.productId,
    required this.name,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    required this.discount,
    required this.lineTotal,
    this.imageUrl,
  });

  final int productId;
  final String name;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discount;
  final double lineTotal;
  final String? imageUrl;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory QuotationLine.fromJson(Map<String, dynamic> j) => QuotationLine(
        productId: j['productId'] as int,
        name: (j['name'] as String?) ?? 'Item',
        sku: j['sku'] as String?,
        quantity: _d(j['quantity']),
        unitPrice: _d(j['unitPrice']),
        taxPercent: _d(j['taxPercent']),
        discount: _d(j['discount']),
        lineTotal: _d(j['lineTotal']),
        imageUrl: (j['imageUrl'] as String?)?.isNotEmpty == true
            ? j['imageUrl'] as String
            : null,
      );
}

/// A merchant-built quotation sent to a linked customer for acceptance.
class Quotation {
  const Quotation({
    required this.id,
    required this.quotationNo,
    required this.status,
    required this.partyName,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.items,
    required this.createdAt,
    this.note,
    this.declineNote,
    this.invoiceId,
    this.invoiceNo,
  });

  final int id;
  final String quotationNo;
  final String status; // REQUESTED | PENDING | ACCEPTED | DECLINED | CANCELLED | EXPIRED
  final String partyName;
  final double subtotal;
  final double taxAmount;
  final double total;
  final List<QuotationLine> items;
  final DateTime createdAt;
  final String? note;
  final String? declineNote;
  final int? invoiceId;
  final String? invoiceNo;

  bool get isPending => status == 'PENDING';

  /// A customer-initiated quote awaiting the merchant's pricing.
  bool get isRequested => status == 'REQUESTED';

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory Quotation.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    final invoice = j['invoice'] as Map<String, dynamic>?;
    final items = (j['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuotationLine.fromJson)
        .toList();
    return Quotation(
      id: j['id'] as int,
      quotationNo: j['quotationNo'] as String,
      status: j['status'] as String,
      partyName: (party?['name'] as String?) ?? 'Customer',
      subtotal: _d(j['subtotal']),
      taxAmount: _d(j['taxAmount']),
      total: _d(j['total']),
      items: items,
      createdAt: DateTime.parse(j['createdAt'] as String),
      note: j['note'] as String?,
      declineNote: j['declineNote'] as String?,
      invoiceId: invoice?['id'] as int?,
      invoiceNo: invoice?['invoiceNo'] as String?,
    );
  }
}
