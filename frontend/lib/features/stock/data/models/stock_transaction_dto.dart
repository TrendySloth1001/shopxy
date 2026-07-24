import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class StockTransactionDto {
  static StockTransaction fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final vendor = json['vendor'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    return StockTransaction(
      id: json['id'].toString(),
      productId: json['productId'].toString(),
      type: json['type'] as String? ?? 'STOCK_IN',
      direction: json['direction'] as String? ??
          (json['type'] == 'STOCK_OUT' ? 'OUT' : 'IN'),
      reasonCode: json['reasonCode'] as String? ??
          (json['type'] == 'STOCK_OUT' ? 'SHRINKAGE' : 'PURCHASE'),
      sourceType: json['sourceType'] as String? ?? 'MANUAL',
      sourceId: json['sourceId']?.toString(),
      sourceLineId: json['sourceLineId']?.toString(),
      quantity: _toDouble(json['quantity']),
      unitPrice: json['unitPrice'] != null ? _toDouble(json['unitPrice']) : null,
      unitCost: json['unitCost'] != null ? _toDouble(json['unitCost']) : null,
      totalValue:
          json['totalValue'] != null ? _toDouble(json['totalValue']) : null,
      stockBefore:
          json['stockBefore'] != null ? _toDouble(json['stockBefore']) : null,
      stockAfter:
          json['stockAfter'] != null ? _toDouble(json['stockAfter']) : null,
      supplierName: json['supplierName'] as String?,
      vendorId: vendor?['id']?.toString(),
      vendorName: vendor?['name'] as String?,
      purchasePriceMode: json['purchasePriceMode'] as String?,
      purchasePriceBefore: json['purchasePriceBefore'] != null
          ? _toDouble(json['purchasePriceBefore'])
          : null,
      purchasePriceAfter: json['purchasePriceAfter'] != null
          ? _toDouble(json['purchasePriceAfter'])
          : null,
      reversesId: json['reversesId']?.toString(),
      createdById: createdBy?['id']?.toString(),
      createdByName: createdBy?['name'] as String?,
      note: json['note'] as String?,
      productName: product?['name'] as String?,
      productSku: product?['sku'] as String?,
      productUnit: product?['unit'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, dynamic> toCreateJson({
    required String productId,
    required String type,
    required double quantity,
    double? unitPrice,
    String? vendorId,
    String? partyId,
    String? note,
  }) {
    final data = <String, dynamic>{
      'productId': productId,
      'type': type,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'vendorId': vendorId,
      'partyId': partyId,
      'note': (note != null && note.isNotEmpty) ? note : null,
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }
}
