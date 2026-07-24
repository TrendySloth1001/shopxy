// Customer-side projections of the backend ReturnRequest models.

import 'package:shopxy_customer/shared/format/json_parse.dart';

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
      return 'Changed my mind';
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

class ReturnEvent {
  const ReturnEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.note,
  });
  final String id;
  final String type;
  final DateTime occurredAt;
  final String? note;

  factory ReturnEvent.fromJson(Map<String, dynamic> j) => ReturnEvent(
        id: j['id'].toString(),
        type: j['type'] as String,
        occurredAt: parseDate(j['occurredAt']),
        note: j['note'] as String?,
      );
}

class ReturnItem {
  const ReturnItem({
    required this.id,
    required this.purchaseRequestItemId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.refundAmount,
    required this.reason,
    required this.originalQuantity,
    this.imageUrl,
  });
  final String id;
  final String purchaseRequestItemId;
  final String productId;
  final String productName;
  final String unit;
  final double unitPrice;
  final double quantity;
  final double refundAmount;
  final String reason;
  final double originalQuantity;
  final String? imageUrl;

  factory ReturnItem.fromJson(Map<String, dynamic> j) {
    final pri = j['purchaseRequestItem'] as Map<String, dynamic>;
    final imgs = (pri['product'] as Map<String, dynamic>?)?['images'] as List?;
    final firstImage = imgs != null && imgs.isNotEmpty
        ? (imgs.first as Map<String, dynamic>)['url'] as String?
        : null;
    return ReturnItem(
      id: j['id'].toString(),
      purchaseRequestItemId: pri['id'].toString(),
      productId: pri['productId'].toString(),
      productName: pri['productName'] as String,
      unit: (pri['unit'] as String?) ?? 'PCS',
      unitPrice: _d(pri['unitPrice']),
      quantity: _d(j['quantity']),
      refundAmount: _d(j['refundAmount']),
      reason: j['reason'] as String,
      originalQuantity: _d(pri['quantity']),
      imageUrl: firstImage,
    );
  }
}

class ReturnShop {
  const ReturnShop({required this.id, required this.name, required this.slug});
  final String id;
  final String name;
  final String slug;
  factory ReturnShop.fromJson(Map<String, dynamic> j) => ReturnShop(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? '',
        slug: (j['slug'] as String?) ?? '',
      );
}

class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.status,
    required this.refundAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.shop,
    required this.parentOrderId,
    required this.shopOrderId,
    required this.items,
    required this.events,
    this.refundMethod,
    this.note,
    this.decisionNote,
    this.walletEntryId,
  });

  final String id;
  /// REQUESTED / APPROVED / REJECTED / CANCELLED / PICKED_UP /
  /// RECEIVED / REFUNDED.
  final String status;
  final double refundAmount;
  final String? refundMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReturnShop shop;
  /// Parent CustomerOrder id — useful for "back to order" navigation.
  final String parentOrderId;
  /// Underlying PurchaseRequest id.
  final String shopOrderId;
  final List<ReturnItem> items;
  final List<ReturnEvent> events;
  final String? note;
  final String? decisionNote;
  final String? walletEntryId;

  bool get isOpen =>
      status == 'REQUESTED' ||
      status == 'APPROVED' ||
      status == 'PICKED_UP' ||
      status == 'RECEIVED';
  bool get canCancel => status == 'REQUESTED';
  bool get isRefunded => status == 'REFUNDED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  factory ReturnRequest.fromJson(Map<String, dynamic> j) {
    final request = j['request'] as Map<String, dynamic>;
    return ReturnRequest(
      id: j['id'].toString(),
      status: j['status'] as String,
      refundAmount: _d(j['refundAmount']),
      refundMethod: j['refundMethod'] as String?,
      createdAt: parseDate(j['createdAt']),
      updatedAt: parseDate(j['updatedAt']),
      shop: ReturnShop.fromJson(j['shop'] as Map<String, dynamic>),
      parentOrderId: request['customerOrderId'].toString(),
      shopOrderId: request['id'].toString(),
      items: ((j['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReturnItem.fromJson)
          .toList(),
      events: ((j['events'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReturnEvent.fromJson)
          .toList(),
      note: j['note'] as String?,
      decisionNote: j['decisionNote'] as String?,
      walletEntryId: j['walletEntryId']?.toString(),
    );
  }
}
