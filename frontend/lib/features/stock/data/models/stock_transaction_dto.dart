import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class StockTransactionDto {
  static StockTransaction fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final vendor = json['vendor'] as Map<String, dynamic>?;
    return StockTransaction(
      id: json['id'] as int,
      productId: json['productId'] as int,
      type: json['type'] as String,
      quantity: _toDouble(json['quantity']),
      unitPrice: json['unitPrice'] != null ? _toDouble(json['unitPrice']) : null,
      supplierName: json['supplierName'] as String?,
      vendorId: vendor?['id'] as int?,
      vendorName: vendor?['name'] as String?,
      purchasePriceMode: json['purchasePriceMode'] as String?,
      purchasePriceBefore: json['purchasePriceBefore'] != null
          ? _toDouble(json['purchasePriceBefore'])
          : null,
      purchasePriceAfter: json['purchasePriceAfter'] != null
          ? _toDouble(json['purchasePriceAfter'])
          : null,
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
    required int productId,
    required String type,
    required double quantity,
    double? unitPrice,
    String? supplierName,
    int? vendorId,
    String? purchasePriceMode,
    String? note,
  }) {
    final data = <String, dynamic>{
      'productId': productId,
      'type': type,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'supplierName': (supplierName != null && supplierName.trim().isNotEmpty)
          ? supplierName.trim()
          : null,
      'vendorId': vendorId,
      'purchasePriceMode': purchasePriceMode,
      'note': (note != null && note.isNotEmpty) ? note : null,
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }
}
