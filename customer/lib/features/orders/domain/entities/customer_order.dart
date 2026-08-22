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
  /// 7 days" without a second fetch.
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
      default:
        return 'original payment';
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
    this.documentType = 'TAX_INVOICE',
    this.customerGstin,
  });

  final String id;
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

  /// TAX_INVOICE or BILL_OF_SUPPLY. Only a tax invoice carrying the buyer's
  /// own GSTIN supports an input-credit claim.
  final String documentType;

  /// The GSTIN this document was raised against, when the buyer asked for it.
  final String? customerGstin;

  /// Whether this document actually supports an ITC claim: a tax invoice, in
  /// the buyer's registered name. A bill of supply carries no GST, and a tax
  /// invoice with no recipient GSTIN is a B2C sale.
  bool get supportsInputCredit =>
      documentType == 'TAX_INVOICE' && (customerGstin?.isNotEmpty ?? false);

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
      id: j['id'].toString(),
      invoiceNo: j['invoiceNo'] as String,
      total: _d(j['total']),
      status: (j['status'] as String?) ?? 'DRAFT',
      paidAmount: _d(j['paidAmount']),
      outstanding: _d(j['outstanding']),
      paymentStatus: (j['paymentStatus'] as String?) ?? 'UNPAID',
      documentType: (j['documentType'] as String?) ?? 'TAX_INVOICE',
      customerGstin: j['customerGstin'] as String?,
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
  final String id;
  final String shopId;
  /// PENDING / CONFIRMED / REJECTED / CANCELLED.
  final String status;
  final double estimatedTotal;
  final int itemCount;
  final List<OrderItemPreview> itemsPreview;
  final OrderShop? shop;
  final String? invoiceId;
  final DateTime? decidedAt;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  factory ShopOrderSummary.fromJson(Map<String, dynamic> j) {
    return ShopOrderSummary(
      id: j['id'].toString(),
      shopId: j['shopId'].toString(),
      status: j['status'] as String,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      itemsPreview: ((j['itemsPreview'] as List?) ?? const [])
          .map((e) => OrderItemPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
      shop: OrderShop.fromJson(j['shop'] as Map<String, dynamic>?),
      invoiceId: j['invoiceId']?.toString(),
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

  final String id;
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
      id: j['id'].toString(),
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
    this.canCancel = false,
    this.canReturn = false,
    this.cancellationPolicy,
    this.deliveredAt,
  });

  final List<CustomerOrderItem> items;
  final String? decisionNote;
  final OrderInvoiceRef? invoice;
  /// Server-computed: true while this slice can still be cancelled
  /// (PENDING always; CONFIRMED until the shop's cancellation-policy
  /// cut-off milestone). The UI must obey this flag instead of deriving
  /// its own rule from [status]. Defaults to false so older cached
  /// payloads without the field simply hide the action.
  final bool canCancel;
  /// Server-computed: true only when the slice is CONFIRMED, a
  /// DELIVERED event exists, the shop has returns enabled and the
  /// return window is still open. Same default-false contract as
  /// [canCancel].
  final bool canReturn;
  /// One of UNTIL_CONFIRMED / UNTIL_PACKED / UNTIL_SHIPPED /
  /// UNTIL_DELIVERED — the shop's cancellation cut-off. Null on older
  /// payloads.
  final String? cancellationPolicy;
  /// When the DELIVERED shipping event was recorded; null until then.
  final DateTime? deliveredAt;
  /// Server-side Party id (the customer's identity at this seller's
  /// shop) — populated when the customer is linked. Used by the
  /// invoice-viewer tap to construct `/me/parties/:id/invoices/:n`.
  final String? linkedPartyId;
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
      id: j['id'].toString(),
      shopId: j['shopId'].toString(),
      status: j['status'] as String,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      shop: OrderShop.fromJson(j['shop'] as Map<String, dynamic>?),
      invoiceId: j['invoiceId']?.toString(),
      decidedAt: j['decidedAt'] == null
          ? null
          : DateTime.parse(j['decidedAt'] as String),
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      decisionNote: j['decisionNote'] as String?,
      invoice:
          OrderInvoiceRef.fromJson(j['invoice'] as Map<String, dynamic>?),
      linkedPartyId: party?['id']?.toString(),
      events: ((j['events'] as List?) ?? const [])
          .map((e) => OrderEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      canCancel: (j['canCancel'] as bool?) ?? false,
      canReturn: (j['canReturn'] as bool?) ?? false,
      cancellationPolicy: j['cancellationPolicy'] as String?,
      deliveredAt: j['deliveredAt'] == null
          ? null
          : DateTime.parse(j['deliveredAt'] as String),
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
      // A locally-patched status is always a cancel — the server flags
      // are stale the moment the slice changes, so drop the actions
      // until the next refetch.
      canCancel: status == null && canCancel,
      canReturn: status == null && canReturn,
      cancellationPolicy: cancellationPolicy,
      deliveredAt: deliveredAt,
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
    this.couponDiscount = 0,
    this.walletPaid = 0,
    this.paymentStatus = 'COD',
    required this.createdAt,
    required this.shopOrderCount,
    required this.shopOrders,
  });

  final String id;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  /// Sum of children's estimated totals — what the customer paid.
  final double estimatedTotal;
  /// Order-level coupon discount (0 when none).
  final double couponDiscount;
  /// Amount paid from wallet at submit (0 when wallet unused).
  final double walletPaid;
  /// Online-payment state of the gateway-payable remainder:
  /// COD / PENDING / PAID / FAILED. Drives Pay Now + home reminder.
  final String paymentStatus;
  final DateTime createdAt;
  /// Number of vendor slices (`_count.shopOrders` from the server).
  final int shopOrderCount;
  final List<ShopOrderSummary> shopOrders;

  /// Total items across every vendor slice.
  int get totalItemCount =>
      shopOrders.fold(0, (sum, s) => sum + s.itemCount);

  /// Amount still payable online: estimatedTotal − coupon − wallet.
  /// Floored at 0 (a fully wallet/coupon-covered order owes nothing).
  double get payableRemainder {
    final r = estimatedTotal - couponDiscount - walletPaid;
    return r > 0 ? r : 0;
  }

  /// True when an online payment is still owed — the order chose online
  /// pay (not COD) and hasn't captured yet. Drives the "Pay Now" button
  /// and the home reminder.
  bool get needsOnlinePayment =>
      (paymentStatus == 'PENDING' || paymentStatus == 'FAILED') &&
      payableRemainder > 0;

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
      id: j['id'].toString(),
      customerName: (j['customerName'] as String?) ?? '',
      customerPhone: j['customerPhone'] as String?,
      customerAddress: j['customerAddress'] as String?,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      couponDiscount: _toDouble(j['couponDiscount']),
      walletPaid: _toDouble(j['walletPaid']),
      paymentStatus: (j['paymentStatus'] as String?) ?? 'COD',
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
      couponDiscount: couponDiscount,
      walletPaid: walletPaid,
      paymentStatus: paymentStatus,
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

  final String id;
  final String productId;
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
      id: j['id'].toString(),
      productId: j['productId'].toString(),
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
    super.couponDiscount,
    super.walletPaid,
    super.paymentStatus,
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
      id: j['id'].toString(),
      customerName: (j['customerName'] as String?) ?? '',
      customerPhone: j['customerPhone'] as String?,
      customerEmail: j['customerEmail'] as String?,
      customerAddress: j['customerAddress'] as String?,
      estimatedTotal: _toDouble(j['estimatedTotal']),
      couponDiscount: _toDouble(j['couponDiscount']),
      walletPaid: _toDouble(j['walletPaid']),
      paymentStatus: (j['paymentStatus'] as String?) ?? 'COD',
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
