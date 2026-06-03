double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Compact item preview for inbox rows. Lets the merchant skim what was
/// ordered without tapping into each row.
class MerchantOrderItemPreview {
  const MerchantOrderItemPreview({
    required this.productName,
    required this.quantity,
    required this.unit,
  });

  final String productName;
  final double quantity;
  final String unit;

  factory MerchantOrderItemPreview.fromJson(Map<String, dynamic> j) {
    return MerchantOrderItemPreview(
      productName: j['productName'] as String,
      quantity: _asDouble(j['quantity']),
      unit: (j['unit'] as String?) ?? 'PCS',
    );
  }
}

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.status,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.estimatedTotal,
    required this.itemCount,
    required this.createdAt,
    this.decidedAt,
    this.invoiceId,
    this.partyId,
    this.partyName,
    this.partyLinkedUserId,
    this.itemPreview = const [],
  });

  final int id;
  final String status;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double estimatedTotal;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final int? invoiceId;
  final int? partyId;
  final String? partyName;
  final int? partyLinkedUserId;
  /// First couple of items (max ~2 from the backend) for the inbox row.
  final List<MerchantOrderItemPreview> itemPreview;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  /// True when the customer was already an invited Party. False means
  /// the merchant will lazy-create a party row on confirm.
  bool get isLinkedCustomer => partyLinkedUserId != null;

  factory MerchantOrder.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    return MerchantOrder(
      id: j['id'] as int,
      status: j['status'] as String,
      customerName: j['customerName'] as String,
      customerPhone: j['customerPhone'] as String?,
      customerEmail: j['customerEmail'] as String?,
      estimatedTotal: _asDouble(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
      invoiceId: j['invoiceId'] as int?,
      partyId: party?['id'] as int?,
      partyName: party?['name'] as String?,
      partyLinkedUserId: party?['linkedUserId'] as int?,
      itemPreview: ((j['itemsPreview'] as List?) ?? const [])
          .map((e) =>
              MerchantOrderItemPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MerchantOrderItem {
  const MerchantOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.stockQuantity,
    this.productActive = true,
    this.productImageUrl,
  });

  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double total;
  /// Live stock of the linked product at fetch time. Null if the
  /// product row has been deleted (FK is Restrict, so this only
  /// happens if a future migration changes that).
  final double? stockQuantity;
  final bool productActive;
  /// First product image (sortOrder asc), if any. Lets the order detail
  /// show thumbnails without a follow-up fetch per row.
  final String? productImageUrl;

  /// True if we can fulfil this line right now. Null stock means we
  /// don't know — treat conservatively as not-ok so the merchant double-
  /// checks before confirming.
  bool get stockOk =>
      productActive && stockQuantity != null && stockQuantity! >= quantity;

  double get shortfall {
    final s = stockQuantity ?? 0;
    return s >= quantity ? 0 : quantity - s;
  }

  factory MerchantOrderItem.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    final images = (product?['images'] as List?) ?? const [];
    String? imageUrl;
    if (images.isNotEmpty) {
      final first = images.first as Map<String, dynamic>;
      imageUrl = first['url'] as String?;
    }
    return MerchantOrderItem(
      id: j['id'] as int,
      productId: j['productId'] as int,
      productName: j['productName'] as String,
      productSku: j['productSku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      quantity: _asDouble(j['quantity']),
      unitPrice: _asDouble(j['unitPrice']),
      total: _asDouble(j['total']),
      stockQuantity:
          product == null ? null : _asDouble(product['stockQuantity']),
      productActive: (product?['isActive'] as bool?) ?? true,
      productImageUrl: imageUrl,
    );
  }
}

class MerchantOrderDetail extends MerchantOrder {
  MerchantOrderDetail({
    required super.id,
    required super.status,
    required super.customerName,
    super.customerPhone,
    super.customerEmail,
    required super.estimatedTotal,
    required super.itemCount,
    required super.createdAt,
    super.decidedAt,
    super.invoiceId,
    super.partyId,
    super.partyName,
    super.partyLinkedUserId,
    super.itemPreview,
    this.customerAddress,
    this.note,
    this.decisionNote,
    this.linkedInvoiceNo,
    this.invoicePaymentStatus,
    this.invoicePaidAmount = 0,
    this.invoiceBalanceDue = 0,
    required this.items,
  });

  final String? customerAddress;
  final String? note;
  final String? decisionNote;
  final String? linkedInvoiceNo;
  /// Payment state of the linked invoice as the backend computed it
  /// (PAID | PARTIAL | UNPAID) — derived from receipts posted against the
  /// invoice, which includes online/wallet payments the customer made.
  /// Null until an invoice exists. Drives the "Paid" step on the journey.
  final String? invoicePaymentStatus;
  final double invoicePaidAmount;
  final double invoiceBalanceDue;
  final List<MerchantOrderItem> items;

  /// True when the linked invoice is fully settled.
  bool get isPaid => invoicePaymentStatus == 'PAID';

  /// True when some — but not all — of the invoice has been received.
  bool get isPartiallyPaid => invoicePaymentStatus == 'PARTIAL';

  /// Any line with insufficient stock? Drives the warning chip on the
  /// inbox row + the warning banner on the detail page.
  bool get hasStockShortfall => items.any((i) => !i.stockOk);

  /// Number of lines we can't fully fulfil right now. Used by the
  /// shortfall banner headline ("3 of 5 items short").
  int get shortItemCount => items.where((i) => !i.stockOk).length;

  /// Subtotal computed from line totals. We use this rather than the
  /// snapshotted `estimatedTotal` so the totals block reflects the
  /// current items (eg. if a future partial-fulfill drops a line).
  double get subtotal =>
      items.fold<double>(0, (acc, i) => acc + i.total);

  factory MerchantOrderDetail.fromJson(Map<String, dynamic> j) {
    final base = MerchantOrder.fromJson(j);
    final invoice = j['invoice'] as Map<String, dynamic>?;
    return MerchantOrderDetail(
      id: base.id,
      status: base.status,
      customerName: base.customerName,
      customerPhone: base.customerPhone,
      customerEmail: base.customerEmail,
      estimatedTotal: base.estimatedTotal,
      itemCount: base.itemCount,
      createdAt: base.createdAt,
      decidedAt: base.decidedAt,
      invoiceId: base.invoiceId,
      partyId: base.partyId,
      partyName: base.partyName,
      partyLinkedUserId: base.partyLinkedUserId,
      itemPreview: base.itemPreview,
      customerAddress: j['customerAddress'] as String?,
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
      linkedInvoiceNo: invoice?['invoiceNo'] as String?,
      // Payment summary the backend attaches to the linked invoice
      // (attachInvoicePaymentSummary). Present only once an invoice exists.
      invoicePaymentStatus: invoice?['paymentStatus'] as String?,
      invoicePaidAmount: _asDouble(invoice?['paidAmount']),
      invoiceBalanceDue: _asDouble(invoice?['balanceDue']),
      items: ((j['items'] as List?) ?? const [])
          .map((e) => MerchantOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
