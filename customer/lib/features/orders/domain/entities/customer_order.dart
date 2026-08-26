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
  final bool returnsEnabled;
  final int returnWindowDays;
  final String refundMode;
  final String? returnPolicyNote;

  String get displayName => name ?? ownerName ?? 'Your shop';

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
  final String status;
  final double paidAmount;
  final double outstanding;
  final String paymentStatus;

  final String documentType;

  final String? customerGstin;

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

  final String id;
  final String shopId;
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
  final String type;
  final DateTime occurredAt;
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
  final bool canCancel;
  final bool canReturn;
  final String? cancellationPolicy;
  final DateTime? deliveredAt;
  final String? linkedPartyId;
  final List<OrderEvent> events;

  String? get linkedInvoiceNo => invoice?.invoiceNo;

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
      canCancel: status == null && canCancel,
      canReturn: status == null && canReturn,
      cancellationPolicy: cancellationPolicy,
      deliveredAt: deliveredAt,
    );
  }
}

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
  final double estimatedTotal;
  final double couponDiscount;
  final double walletPaid;
  final String paymentStatus;
  final DateTime createdAt;
  final int shopOrderCount;
  final List<ShopOrderSummary> shopOrders;

  int get totalItemCount =>
      shopOrders.fold(0, (sum, s) => sum + s.itemCount);

  double get payableRemainder {
    final r = estimatedTotal - couponDiscount - walletPaid;
    return r > 0 ? r : 0;
  }

  bool get needsOnlinePayment =>
      (paymentStatus == 'PENDING' || paymentStatus == 'FAILED') &&
      payableRemainder > 0;

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
