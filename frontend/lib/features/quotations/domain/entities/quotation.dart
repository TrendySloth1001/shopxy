class QuotationLine {
  const QuotationLine({
    required this.productId,
    required this.name,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    this.isPriceInclusive = false,
    required this.discount,
    required this.lineTotal,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double taxPercent;

  final bool isPriceInclusive;
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
        productId: j['productId'].toString(),
        name: (j['name'] as String?) ?? 'Item',
        sku: j['sku'] as String?,
        quantity: _d(j['quantity']),
        unitPrice: _d(j['unitPrice']),
        taxPercent: _d(j['taxPercent']),
        isPriceInclusive: j['isPriceInclusive'] as bool? ?? false,
        discount: _d(j['discount']),
        lineTotal: _d(j['lineTotal']),
        imageUrl: (j['imageUrl'] as String?)?.isNotEmpty == true
            ? j['imageUrl'] as String
            : null,
      );
}

class Quotation {
  const Quotation({
    required this.id,
    required this.quotationNo,
    required this.status,
    required this.partyName,
    this.partyId,
    this.placeOfSupplyStateCode,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.items,
    required this.createdAt,
    this.archivedAt,
    this.note,
    this.declineNote,
    this.invoiceId,
    this.invoiceNo,
  });

  final String id;
  final String quotationNo;
  final String status;
  final String partyName;

  final String? partyId;

  final String? placeOfSupplyStateCode;
  final double subtotal;
  final double taxAmount;
  final double total;
  final List<QuotationLine> items;
  final DateTime createdAt;

  final DateTime? archivedAt;
  final String? note;
  final String? declineNote;
  final String? invoiceId;
  final String? invoiceNo;

  bool get isPending => status == 'PENDING';

  bool get isRequested => status == 'REQUESTED';

  bool get isArchived => archivedAt != null;

  bool get isAwaitingCounterparty => isPending || isRequested;

  Quotation copyWith({String? status, DateTime? archivedAt, bool clearArchivedAt = false}) {
    return Quotation(
      id: id,
      quotationNo: quotationNo,
      status: status ?? this.status,
      partyName: partyName,
      partyId: partyId,
      placeOfSupplyStateCode: placeOfSupplyStateCode,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      items: items,
      createdAt: createdAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      note: note,
      declineNote: declineNote,
      invoiceId: invoiceId,
      invoiceNo: invoiceNo,
    );
  }

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
      id: j['id'].toString(),
      quotationNo: j['quotationNo'] as String,
      status: j['status'] as String,
      partyName: (party?['name'] as String?) ?? 'Customer',
      partyId: party?['id']?.toString(),
      placeOfSupplyStateCode: j['placeOfSupplyStateCode'] as String?,
      subtotal: _d(j['subtotal']),
      taxAmount: _d(j['taxAmount']),
      total: _d(j['total']),
      items: items,
      createdAt: DateTime.parse(j['createdAt'] as String),
      archivedAt: j['archivedAt'] != null
          ? DateTime.parse(j['archivedAt'] as String)
          : null,
      note: j['note'] as String?,
      declineNote: j['declineNote'] as String?,
      invoiceId: invoice?['id']?.toString(),
      invoiceNo: invoice?['invoiceNo'] as String?,
    );
  }
}
