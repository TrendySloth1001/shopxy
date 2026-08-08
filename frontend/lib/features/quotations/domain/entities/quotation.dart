/// One line in a quotation — a product the merchant added to the bucket.
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

  /// Whether [unitPrice] already contains GST. Frozen onto the line at
  /// quote-creation time from the product's own pricingMode (see
  /// resolveProductPricing on the backend), not re-resolved at accept time —
  /// so the quoted total can't drift from what the customer already saw.
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

/// A merchant-built quotation sent to a linked customer for acceptance.
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
  final String status; // REQUESTED | PENDING | ACCEPTED | DECLINED | CANCELLED | EXPIRED
  final String partyName;

  /// The linked customer's id — needed to spawn a *new* quotation from a loaded
  /// one (the pricing calculator's round-trip). Null for legacy payloads.
  final String? partyId;

  /// Place-of-supply state code carried through when re-pricing a request.
  final String? placeOfSupplyStateCode;
  final double subtotal;
  final double taxAmount;
  final double total;
  final List<QuotationLine> items;
  final DateTime createdAt;

  /// Set once the merchant files this quotation out of their working list.
  /// The row and its number stay put — the quotation serial is allocated at
  /// create time, so a quotation is never deleted. Merchant-side only: the
  /// customer still sees it in their own list.
  final DateTime? archivedAt;
  final String? note;
  final String? declineNote;
  final String? invoiceId;
  final String? invoiceNo;

  bool get isPending => status == 'PENDING';

  /// A customer-initiated quote awaiting the merchant's pricing.
  bool get isRequested => status == 'REQUESTED';

  bool get isArchived => archivedAt != null;

  /// Whether the customer could still act on this — the states archiving is
  /// refused in, because a quote the merchant can't see is one nobody chases.
  bool get isAwaitingCounterparty => isPending || isRequested;

  /// Local echo of a state change, so a screen can reflect one field without
  /// refetching. Exists because the alternative — rebuilding the whole object
  /// by hand at each call site — silently drops every field added later.
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
