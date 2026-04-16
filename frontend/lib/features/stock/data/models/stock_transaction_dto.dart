import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class StockTransactionDto {
  static StockTransaction fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return StockTransaction(
      id: json['id'] as int,
      productId: json['productId'] as int,
      type: json['type'] as String,
      quantity: _toDouble(json['quantity']),
      unitPrice: json['unitPrice'] != null ? _toDouble(json['unitPrice']) : null,
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
    String? note,
  }) {
    return {
      'productId': productId,
      'type': type,
      'quantity': quantity,
      if (unitPrice != null) 'unitPrice': unitPrice,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }
}
