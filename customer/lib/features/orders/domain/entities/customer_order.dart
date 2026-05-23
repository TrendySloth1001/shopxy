/// Identity of the shop a customer order belongs to. Surfaced so the
/// customer can tell which shop placed/handled the order — important for
/// multi-shop users. Values fall back to placeholders when the backend
/// hasn't populated the shop record (single-tenant deployments).
class OrderShop {
  const OrderShop({this.name, this.ownerName});
  final String? name;
  final String? ownerName;

  /// Best display string the UI can use without further fallback logic.
  String get displayName => name ?? ownerName ?? 'Your shop';

  static OrderShop? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return OrderShop(
      name: j['shopName'] as String?,
      ownerName: j['name'] as String?,
    );
  }
}

/// Linked invoice summary on the customer's order — populated only when
/// the merchant has confirmed and the order has been materialised into
/// an invoice. We surface the real `total` so the customer sees the
/// merchant's recomputed amount (with GST / discount) instead of just
/// the cart's estimate.
class OrderInvoiceRef {
  const OrderInvoiceRef({
    required this.id,
    required this.invoiceNo,
    required this.total,
    required this.status,
  });

  final int id;
  final String invoiceNo;
  final double total;
  final String status;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static OrderInvoiceRef? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return OrderInvoiceRef(
      id: j['id'] as int,
      invoiceNo: j['invoiceNo'] as String,
      total: _d(j['total']),
      status: (j['status'] as String?) ?? 'DRAFT',
    );
  }
}

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
    this.itemPreview = const [],
    this.shop,
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
  /// First couple of items so the list row can show "Solder Wire, …"
  /// without a follow-up fetch.
  final List<OrderItemPreview> itemPreview;
  final OrderShop? shop;

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
      itemPreview: ((j['itemsPreview'] as List?) ?? const [])
          .map((e) => OrderItemPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
      shop: OrderShop.fromJson(j['shop'] as Map<String, dynamic>?),
    );
  }

  CustomerOrder copyWith({
    String? status,
    DateTime? decidedAt,
  }) {
    return CustomerOrder(
      id: id,
      status: status ?? this.status,
      customerName: customerName,
      customerPhone: customerPhone,
      estimatedTotal: estimatedTotal,
      itemCount: itemCount,
      createdAt: createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
      invoiceId: invoiceId,
      itemPreview: itemPreview,
      shop: shop,
    );
  }
}

class OrderItemPreview {
  const OrderItemPreview({
    required this.productName,
    required this.quantity,
    required this.unit,
  });

  final String productName;
  final double quantity;
  final String unit;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory OrderItemPreview.fromJson(Map<String, dynamic> j) {
    return OrderItemPreview(
      productName: j['productName'] as String,
      quantity: _d(j['quantity']),
      unit: (j['unit'] as String?) ?? 'PCS',
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
    super.itemPreview,
    super.shop,
    required this.items,
    this.note,
    this.decisionNote,
    this.linkedInvoice,
  });

  final List<CustomerOrderItem> items;
  final String? note;
  final String? decisionNote;
  final OrderInvoiceRef? linkedInvoice;

  String? get linkedInvoiceNo => linkedInvoice?.invoiceNo;

  factory CustomerOrderDetail.fromJson(Map<String, dynamic> j) {
    final base = CustomerOrder.fromJson(j);
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
      itemPreview: base.itemPreview,
      shop: base.shop,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
      linkedInvoice: OrderInvoiceRef.fromJson(j['invoice'] as Map<String, dynamic>?),
    );
  }
}
