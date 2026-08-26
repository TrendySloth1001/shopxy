double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

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

  final String id;
  final String status;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double estimatedTotal;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? invoiceId;
  final String? partyId;
  final String? partyName;
  final String? partyLinkedUserId;
  final List<MerchantOrderItemPreview> itemPreview;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  bool get isLinkedCustomer => partyLinkedUserId != null;

  factory MerchantOrder.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    return MerchantOrder(
      id: j['id'].toString(),
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
      invoiceId: j['invoiceId']?.toString(),
      partyId: party?['id']?.toString(),
      partyName: party?['name'] as String?,
      partyLinkedUserId: party?['linkedUserId']?.toString(),
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

  final String id;
  final String productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double total;
  final double? stockQuantity;
  final bool productActive;
  final String? productImageUrl;

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
      id: j['id'].toString(),
      productId: j['productId'].toString(),
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

class MerchantOrderEvent {
  const MerchantOrderEvent({
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

  String get label {
    switch (type) {
      case 'PACKED':
        return 'Packed';
      case 'SHIPPED':
        return 'Shipped';
      case 'OUT_FOR_DELIVERY':
        return 'Out for delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'RETURNED':
        return 'Returned';
      default:
        return type;
    }
  }

  factory MerchantOrderEvent.fromJson(Map<String, dynamic> j) {
    return MerchantOrderEvent(
      id: j['id'].toString(),
      type: j['type'] as String,
      occurredAt: DateTime.parse(j['occurredAt'] as String),
      courier: j['courier'] as String?,
      awb: j['awb'] as String?,
      eta: j['eta'] == null ? null : DateTime.tryParse(j['eta'] as String),
      note: j['note'] as String?,
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
    this.events = const [],
  });

  final String? customerAddress;
  final String? note;
  final String? decisionNote;
  final String? linkedInvoiceNo;
  final String? invoicePaymentStatus;
  final double invoicePaidAmount;
  final double invoiceBalanceDue;
  final List<MerchantOrderItem> items;
  final List<MerchantOrderEvent> events;

  bool get isPaid => invoicePaymentStatus == 'PAID';

  bool get isPartiallyPaid => invoicePaymentStatus == 'PARTIAL';

  bool get hasStockShortfall => items.any((i) => !i.stockOk);

  int get shortItemCount => items.where((i) => !i.stockOk).length;

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
      invoicePaymentStatus: invoice?['paymentStatus'] as String?,
      invoicePaidAmount: _asDouble(invoice?['paidAmount']),
      invoiceBalanceDue: _asDouble(invoice?['balanceDue']),
      items: ((j['items'] as List?) ?? const [])
          .map((e) => MerchantOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: ((j['events'] as List?) ?? const [])
          .map((e) => MerchantOrderEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
