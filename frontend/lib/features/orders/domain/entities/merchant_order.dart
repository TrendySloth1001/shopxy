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

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  /// True when the customer was already an invited Party. False means
  /// the merchant will lazy-create a party row on confirm.
  bool get isLinkedCustomer => partyLinkedUserId != null;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MerchantOrder.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    return MerchantOrder(
      id: j['id'] as int,
      status: j['status'] as String,
      customerName: j['customerName'] as String,
      customerPhone: j['customerPhone'] as String?,
      customerEmail: j['customerEmail'] as String?,
      estimatedTotal: _d(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
      invoiceId: j['invoiceId'] as int?,
      partyId: party?['id'] as int?,
      partyName: party?['name'] as String?,
      partyLinkedUserId: party?['linkedUserId'] as int?,
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
  });

  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double total;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MerchantOrderItem.fromJson(Map<String, dynamic> j) {
    return MerchantOrderItem(
      id: j['id'] as int,
      productId: j['productId'] as int,
      productName: j['productName'] as String,
      productSku: j['productSku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      quantity: _d(j['quantity']),
      unitPrice: _d(j['unitPrice']),
      total: _d(j['total']),
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
    this.customerAddress,
    this.note,
    this.decisionNote,
    this.linkedInvoiceNo,
    required this.items,
  });

  final String? customerAddress;
  final String? note;
  final String? decisionNote;
  final String? linkedInvoiceNo;
  final List<MerchantOrderItem> items;

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
      customerAddress: j['customerAddress'] as String?,
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
      linkedInvoiceNo: invoice?['invoiceNo'] as String?,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => MerchantOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
