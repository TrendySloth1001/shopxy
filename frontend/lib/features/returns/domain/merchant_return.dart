const List<String> kReturnReasons = [
  'DAMAGED',
  'WRONG_ITEM',
  'NOT_AS_DESCRIBED',
  'SIZE_FIT',
  'CHANGED_MIND',
  'DEFECTIVE',
  'OTHER',
];

String reasonLabel(String code) {
  switch (code) {
    case 'DAMAGED':
      return 'Damaged on arrival';
    case 'WRONG_ITEM':
      return 'Wrong item sent';
    case 'NOT_AS_DESCRIBED':
      return 'Not as described';
    case 'SIZE_FIT':
      return 'Size / fit issue';
    case 'CHANGED_MIND':
      return 'Buyer changed mind';
    case 'DEFECTIVE':
      return 'Defective / not working';
    case 'OTHER':
    default:
      return 'Other';
  }
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class MerchantReturnEvent {
  const MerchantReturnEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.note,
  });
  final String id;
  final String type;
  final DateTime occurredAt;
  final String? note;

  factory MerchantReturnEvent.fromJson(Map<String, dynamic> j) =>
      MerchantReturnEvent(
        id: j['id'].toString(),
        type: j['type'] as String,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        note: j['note'] as String?,
      );
}

class MerchantReturnItem {
  const MerchantReturnItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.refundAmount,
    required this.reason,
    this.imageUrl,
  });
  final String id;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double refundAmount;
  final String reason;
  final String? imageUrl;

  factory MerchantReturnItem.fromJson(Map<String, dynamic> j) {
    final pri = j['purchaseRequestItem'] as Map<String, dynamic>;
    final imgs = (pri['product'] as Map<String, dynamic>?)?['images'] as List?;
    final firstImage = imgs != null && imgs.isNotEmpty
        ? (imgs.first as Map<String, dynamic>)['url'] as String?
        : null;
    return MerchantReturnItem(
      id: j['id'].toString(),
      productName: pri['productName'] as String,
      quantity: _d(j['quantity']),
      unit: (pri['unit'] as String?) ?? 'PCS',
      unitPrice: _d(pri['unitPrice']),
      refundAmount: _d(j['refundAmount']),
      reason: j['reason'] as String,
      imageUrl: firstImage,
    );
  }
}

class MerchantReturn {
  const MerchantReturn({
    required this.id,
    required this.status,
    required this.refundAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.parentOrderId,
    required this.shopOrderId,
    required this.customerUserId,
    required this.customerName,
    required this.customerAddress,
    required this.items,
    required this.events,
    this.refundMethod,
    this.note,
    this.decisionNote,
  });

  final String id;
  final String status;
  final double refundAmount;
  final String? refundMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String parentOrderId;
  final String shopOrderId;
  final String customerUserId;
  final String customerName;
  final String? customerAddress;
  final List<MerchantReturnItem> items;
  final List<MerchantReturnEvent> events;
  final String? note;
  final String? decisionNote;

  bool get canApprove => status == 'REQUESTED';
  bool get canReject => status == 'REQUESTED';
  bool get canMarkPickedUp => status == 'APPROVED';
  bool get canMarkReceived => status == 'PICKED_UP' || status == 'APPROVED';
  bool get canRefund =>
      status == 'RECEIVED' || status == 'APPROVED' || status == 'PICKED_UP';
  bool get isClosed =>
      status == 'REFUNDED' ||
      status == 'REJECTED' ||
      status == 'CANCELLED';

  factory MerchantReturn.fromJson(Map<String, dynamic> j) {
    final request = j['request'] as Map<String, dynamic>;
    return MerchantReturn(
      id: j['id'].toString(),
      status: j['status'] as String,
      refundAmount: _d(j['refundAmount']),
      refundMethod: j['refundMethod'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      parentOrderId: request['customerOrderId'].toString(),
      shopOrderId: request['id'].toString(),
      customerUserId: j['customerUserId'].toString(),
      customerName: (request['customerName'] as String?) ?? 'Customer',
      customerAddress: request['customerAddress'] as String?,
      items: ((j['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MerchantReturnItem.fromJson)
          .toList(),
      events: ((j['events'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MerchantReturnEvent.fromJson)
          .toList(),
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
    );
  }
}
