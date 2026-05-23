class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.status,
    required this.customerName,
    this.customerPhone,
    required this.estimatedTotal,
    required this.itemCount,
    required this.createdAt,
    this.decidedAt,
    this.invoiceId,
  });

  final int id;
  final String status; // PENDING | CONFIRMED | REJECTED | CANCELLED
  final String customerName;
  final String? customerPhone;
  final double estimatedTotal;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final int? invoiceId;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    return CustomerOrder(
      id: j['id'] as int,
      status: j['status'] as String,
      customerName: j['customerName'] as String,
      customerPhone: j['customerPhone'] as String?,
      estimatedTotal: _d(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
      invoiceId: j['invoiceId'] as int?,
    );
  }
}

class CustomerOrderItem {
  const CustomerOrderItem({
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

  factory CustomerOrderItem.fromJson(Map<String, dynamic> j) {
    return CustomerOrderItem(
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

class CustomerOrderDetail extends CustomerOrder {
  CustomerOrderDetail({
    required super.id,
    required super.status,
    required super.customerName,
    super.customerPhone,
    required super.estimatedTotal,
    required super.itemCount,
    required super.createdAt,
    super.decidedAt,
    super.invoiceId,
    required this.items,
    this.note,
    this.decisionNote,
    this.linkedInvoiceNo,
  });

  final List<CustomerOrderItem> items;
  final String? note;
  final String? decisionNote;
  final String? linkedInvoiceNo;

  factory CustomerOrderDetail.fromJson(Map<String, dynamic> j) {
    final base = CustomerOrder.fromJson(j);
    final invoice = j['invoice'] as Map<String, dynamic>?;
    return CustomerOrderDetail(
      id: base.id,
      status: base.status,
      customerName: base.customerName,
      customerPhone: base.customerPhone,
      estimatedTotal: base.estimatedTotal,
      itemCount: base.itemCount,
      createdAt: base.createdAt,
      decidedAt: base.decidedAt,
      invoiceId: base.invoiceId,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
      linkedInvoiceNo: invoice?['invoiceNo'] as String?,
    );
  }
}
