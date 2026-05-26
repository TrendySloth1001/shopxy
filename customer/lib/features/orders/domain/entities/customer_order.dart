/// Identity of the shop a single per-vendor slice belongs to.
/// Surfaced so the customer can tell which shop is fulfilling which
/// part of the order. Values fall back to placeholders when the
/// backend hasn't populated the shop record.
class OrderShop {
  const OrderShop({
    this.name,
    this.ownerName,
    this.returnsEnabled = true,
    this.returnWindowDays = 7,
    this.refundMode = 'WALLET',
    this.returnPolicyNote,
  });
  final String? name;
  final String? ownerName;
  /// Buyer-facing return policy summary — populated on the per-slice
  /// detail payload so the order detail page can show "Returns within
  /// 7 days · wallet refund" without a second fetch.
  final bool returnsEnabled;
  final int returnWindowDays;
  /// WALLET / ORIGINAL / REPLACEMENT.
  final String refundMode;
  final String? returnPolicyNote;

  /// Best display string the UI can use without further fallback logic.
  String get displayName => name ?? ownerName ?? 'Your shop';

  /// Short human label for the refund mode chip.
  String get refundModeLabel {
    switch (refundMode) {
      case 'ORIGINAL':
        return 'original payment';
      case 'REPLACEMENT':
        return 'replacement only';
      case 'WALLET':
      default:
        return 'wallet refund';
    }
  }

  static OrderShop? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return OrderShop(
      name: j['shopName'] as String?,
      ownerName: j['name'] as String?,
      returnsEnabled: (j['returnsEnabled'] as bool?) ?? true,
      returnWindowDays: (j['returnWindowDays'] as num?)?.toInt() ?? 7,
      refundMode: (j['refundMode'] as String?) ?? 'WALLET',
      returnPolicyNote: j['returnPolicyNote'] as String?,
    );
  }
}

/// Linked invoice summary on a per-vendor slice — populated only once
/// the merchant has confirmed and the slice has been materialised into
/// an invoice. The customer sees the merchant's recomputed total here
/// (GST / discount applied) instead of the cart's pre-confirm estimate.
class OrderInvoiceRef {
  const OrderInvoiceRef({
    required this.id,
    required this.invoiceNo,
    required this.total,
    required this.status,
    this.paidAmount = 0,
    this.outstanding = 0,
    this.paymentStatus = 'UNPAID',
  });

  final int id;
  final String invoiceNo;
  final double total;
  /// Lifecycle status (DRAFT / CONFIRMED / CANCELLED) — separate from
  /// [paymentStatus] below.
  final String status;
  /// Sum of payments received against this invoice (server-derived).
  final double paidAmount;
  /// Total − paidAmount, floored at 0.
  final double outstanding;
  /// One of UNPAID / PARTIALLY_PAID / PAID.
  final String paymentStatus;

  bool get isPaid => paymentStatus == 'PAID';
  bool get isPartiallyPaid => paymentStatus == 'PARTIALLY_PAID';

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
      paidAmount: _d(j['paidAmount']),
      outstanding: _d(j['outstanding']),
      paymentStatus: (j['paymentStatus'] as String?) ?? 'UNPAID',
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// One product line inside a per-vendor slice's preview ("3 × Solder
/// Wire Roll, …"). Used in list rows; the full detail page uses the
/// richer [CustomerOrderItem] below.
class OrderItemPreview {
  const OrderItemPreview({
    required this.productName,
    required this.quantity,
    required this.unit,
  });

  final String productName;
  final double quantity;
  final String unit;

  factory OrderItemPreview.fromJson(Map<String, dynamic> j) {
    return OrderItemPreview(
      productName: j['productName'] as String,
      quantity: _toDouble(j['quantity']),
      unit: (j['unit'] as String?) ?? 'PCS',
    );
  }
}

/// One vendor's slice of a [CustomerOrder] as it appears in the list
/// view: status pill, subtotal, item count, preview lines. Detail
/// pages use [ShopOrderDetail] which inherits the same shape plus the
/// full items array and invoice link.
class ShopOrderSummary {
  ShopOrderSummary({
    required this.id,
    required this.shopId,
    required this.status,
    required this.estimatedTotal,
    required this.itemCount,
    this.itemsPreview = const [],
    this.shop,
    this.invoiceId,
    this.decidedAt,
  });

  /// Underlying PurchaseRequest id — the merchant's inbox row id.
  /// Used for per-shop cancel.
  final int id;
  final int shopId;
  /// PENDING / CONFIRMED / REJECTED / CANCELLED.
  final String status;
  final double estimatedTotal;
  final int itemCount;
  final List<OrderItemPreview> itemsPreview;
  final OrderShop? shop;
  final int? invoiceId;
  final DateTime? decidedAt;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  factory ShopOrderSummary.fromJson(Map<String, dynamic> j) {
    return ShopOrderSummary(
      id: j['id'] as int,
      shopId: j['shopId'] as int,
      status: j['status'] as String,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      itemsPreview: ((j['itemsPreview'] as List?) ?? const [])
          .map((e) => OrderItemPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
      shop: OrderShop.fromJson(j['shop'] as Map<String, dynamic>?),
      invoiceId: j['invoiceId'] as int?,
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
    );
  }

  ShopOrderSummary copyWith({String? status, DateTime? decidedAt}) {
    return ShopOrderSummary(
      id: id,
      shopId: shopId,
      status: status ?? this.status,
      estimatedTotal: estimatedTotal,
      itemCount: itemCount,
      itemsPreview: itemsPreview,
      shop: shop,
      invoiceId: invoiceId,
      decidedAt: decidedAt ?? this.decidedAt,
    );
  }
}

/// One milestone on a shop-order's timeline — drives the customer-side
/// tracking strip. Server emits CREATED on submit, CONFIRMED on merchant
/// confirm, REJECTED / CANCELLED on the respective decision, and the
/// shipping milestones (PACKED → DELIVERED) when the merchant records
/// them via `POST /orders/:id/events`.
class OrderEvent {
  const OrderEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.courier,
    this.awb,
    this.eta,
    this.note,
  });

  final int id;
  /// One of CREATED / CONFIRMED / REJECTED / CANCELLED / PACKED /
  /// SHIPPED / OUT_FOR_DELIVERY / DELIVERED / RETURNED.
  final String type;
  final DateTime occurredAt;
  /// Courier / AWB / promised delivery date — populated on shipping
  /// rows. Null on lifecycle rows.
  final String? courier;
  final String? awb;
  final DateTime? eta;
  final String? note;

  factory OrderEvent.fromJson(Map<String, dynamic> j) {
    return OrderEvent(
      id: j['id'] as int,
      type: j['type'] as String,
      occurredAt: DateTime.parse(j['occurredAt'] as String),
      courier: j['courier'] as String?,
      awb: j['awb'] as String?,
      eta: j['eta'] == null ? null : DateTime.parse(j['eta'] as String),
      note: j['note'] as String?,
    );
  }
}

/// One vendor's slice in the *detail* view — extends [ShopOrderSummary]
/// with the full items array and invoice ref.
class ShopOrderDetail extends ShopOrderSummary {
  ShopOrderDetail({
    required super.id,
    required super.shopId,
    required super.status,
    required super.estimatedTotal,
    required super.itemCount,
    super.itemsPreview = const [],
    super.shop,
    super.invoiceId,
    super.decidedAt,
    required this.items,
    this.decisionNote,
    this.invoice,
    this.linkedPartyId,
    this.events = const [],
  });

  final List<CustomerOrderItem> items;
  final String? decisionNote;
  final OrderInvoiceRef? invoice;
  /// Server-side Party id (the customer's identity at this seller's
  /// shop) — populated when the customer is linked. Used by the
  /// invoice-viewer tap to construct `/me/parties/:id/invoices/:n`.
  final int? linkedPartyId;
  /// Chronological tracking events for this slice. Empty when the
  /// backend doesn't yet include the timeline (older API versions).
  final List<OrderEvent> events;

  String? get linkedInvoiceNo => invoice?.invoiceNo;

  /// Most recent shipping milestone (PACKED through DELIVERED), or
  /// null when none has been recorded. Used by the order-detail header
  /// to surface "Shipped · ETA Wed 12 Jun" without the customer
  /// having to scroll to the timeline.
  OrderEvent? get latestShippingEvent {
    OrderEvent? best;
    for (final e in events) {
      switch (e.type) {
        case 'PACKED':
        case 'SHIPPED':
        case 'OUT_FOR_DELIVERY':
        case 'DELIVERED':
        case 'RETURNED':
          if (best == null || e.occurredAt.isAfter(best.occurredAt)) best = e;
      }
    }
    return best;
  }

  bool get hasInvoicePdf =>
      invoice != null && (status == 'CONFIRMED' || invoice!.status == 'CONFIRMED');

  factory ShopOrderDetail.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    return ShopOrderDetail(
      id: j['id'] as int,
      shopId: j['shopId'] as int,
      status: j['status'] as String,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      shop: OrderShop.fromJson(j['shop'] as Map<String, dynamic>?),
      invoiceId: j['invoiceId'] as int?,
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      decisionNote: j['decisionNote'] as String?,
      invoice:
          OrderInvoiceRef.fromJson(j['invoice'] as Map<String, dynamic>?),
      linkedPartyId: party?['id'] as int?,
      events: ((j['events'] as List?) ?? const [])
          .map((e) => OrderEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  ShopOrderDetail copyWith({String? status, DateTime? decidedAt}) {
    return ShopOrderDetail(
      id: id,
      shopId: shopId,
      status: status ?? this.status,
      estimatedTotal: estimatedTotal,
      itemCount: itemCount,
      itemsPreview: itemsPreview,
      shop: shop,
      invoiceId: invoiceId,
      decidedAt: decidedAt ?? this.decidedAt,
      items: items,
      decisionNote: decisionNote,
      invoice: invoice,
      linkedPartyId: linkedPartyId,
      events: events,
    );
  }
}

/// One *customer-side* order = one checkout submission. Owns N
/// per-vendor [ShopOrderSummary] children — the customer thinks of
/// the whole thing as "order #123" and the per-vendor split is the
/// fulfilment detail.
class CustomerOrder {
  CustomerOrder({
    required this.id,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.estimatedTotal,
    required this.createdAt,
    required this.shopOrderCount,
    required this.shopOrders,
  });

  final int id;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  /// Sum of children's estimated totals — what the customer paid.
  final double estimatedTotal;
  final DateTime createdAt;
  /// Number of vendor slices (`_count.shopOrders` from the server).
  final int shopOrderCount;
  final List<ShopOrderSummary> shopOrders;

  /// Total items across every vendor slice.
  int get totalItemCount =>
      shopOrders.fold(0, (sum, s) => sum + s.itemCount);

  /// Compact human label: "3 shops confirmed" / "2 confirmed, 1 pending"
  /// / "All cancelled". Built so the list row doesn't need to repeat
  /// the logic.
  String get aggregateStatusLabel {
    if (shopOrders.isEmpty) return 'No vendors';
    final counts = <String, int>{};
    for (final s in shopOrders) {
      counts[s.status] = (counts[s.status] ?? 0) + 1;
    }
    if (counts.length == 1) {
      final only = counts.keys.first;
      switch (only) {
        case 'CONFIRMED':
          return shopOrders.length == 1
              ? 'Confirmed'
              : 'All sellers confirmed';
        case 'PENDING':
          return shopOrders.length == 1
              ? 'Waiting on seller'
              : 'Waiting on ${shopOrders.length} sellers';
        case 'REJECTED':
          return shopOrders.length == 1
              ? 'Rejected'
              : 'All sellers rejected';
        case 'CANCELLED':
          return shopOrders.length == 1
              ? 'Cancelled'
              : 'Cancelled';
        default:
          return only;
      }
    }
    // Mixed — render the breakdown in a stable order.
    final parts = <String>[];
    void add(String key, String label) {
      final c = counts[key] ?? 0;
      if (c > 0) parts.add('$c $label');
    }
    add('CONFIRMED', 'confirmed');
    add('PENDING', 'pending');
    add('REJECTED', 'rejected');
    add('CANCELLED', 'cancelled');
    return parts.join(', ');
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    return CustomerOrder(
      id: j['id'] as int,
      customerName: (j['customerName'] as String?) ?? '',
      customerPhone: j['customerPhone'] as String?,
      customerAddress: j['customerAddress'] as String?,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      createdAt: DateTime.parse(j['createdAt'] as String),
      shopOrderCount:
          ((j['_count'] as Map?)?['shopOrders'] as int?) ?? 0,
      shopOrders: ((j['shopOrders'] as List?) ?? const [])
          .map((e) => ShopOrderSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CustomerOrder copyWith({List<ShopOrderSummary>? shopOrders}) {
    return CustomerOrder(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      estimatedTotal: estimatedTotal,
      createdAt: createdAt,
      shopOrderCount: shopOrderCount,
      shopOrders: shopOrders ?? this.shopOrders,
    );
  }
}

/// One product line of a per-vendor slice in the detail view. Includes
/// the primary product image so the order detail page can render a
/// thumbnail without a follow-up fetch.
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
    this.imageUrl,
  });

  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? imageUrl;

  factory CustomerOrderItem.fromJson(Map<String, dynamic> j) {
    String? firstImageUrl;
    final product = j['product'] as Map<String, dynamic>?;
    final images = product?['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      firstImageUrl =
          (images.first as Map<String, dynamic>)['url'] as String?;
    }
    return CustomerOrderItem(
      id: j['id'] as int,
      productId: j['productId'] as int,
      productName: j['productName'] as String,
      productSku: j['productSku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      quantity: _toDouble(j['quantity']),
      unitPrice: _toDouble(j['unitPrice']),
      total: _toDouble(j['total']),
      imageUrl: firstImageUrl,
    );
  }
}

/// Parent CustomerOrder with full per-vendor details — items, invoice
/// refs, decision notes. Returned by GET /me/orders/:id.
class CustomerOrderDetail extends CustomerOrder {
  CustomerOrderDetail({
    required super.id,
    required super.customerName,
    super.customerPhone,
    super.customerAddress,
    required super.estimatedTotal,
    required super.createdAt,
    required super.shopOrderCount,
    required List<ShopOrderDetail> shopOrders,
    this.note,
    this.customerEmail,
  }) : detailedShopOrders = shopOrders,
       super(shopOrders: shopOrders);

  final String? note;
  final String? customerEmail;
  /// Typed accessor so the detail page can reach the per-vendor items
  /// without down-casting.
  final List<ShopOrderDetail> detailedShopOrders;

  factory CustomerOrderDetail.fromJson(Map<String, dynamic> j) {
    return CustomerOrderDetail(
      id: j['id'] as int,
      customerName: (j['customerName'] as String?) ?? '',
      customerPhone: j['customerPhone'] as String?,
      customerEmail: j['customerEmail'] as String?,
      customerAddress: j['customerAddress'] as String?,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      createdAt: DateTime.parse(j['createdAt'] as String),
      shopOrderCount:
          ((j['_count'] as Map?)?['shopOrders'] as int?) ?? 0,
      shopOrders: ((j['shopOrders'] as List?) ?? const [])
          .map((e) => ShopOrderDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: j['note'] as String?,
    );
  }
}
