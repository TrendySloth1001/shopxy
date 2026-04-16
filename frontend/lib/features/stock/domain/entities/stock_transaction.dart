class StockTransaction {
  const StockTransaction({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.unitPrice,
    this.note,
    this.productName,
    this.productSku,
    this.productUnit,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String type;
  final double quantity;
  final double? unitPrice;
  final String? note;
  final String? productName;
  final String? productSku;
  final String? productUnit;
  final DateTime createdAt;

  bool get isStockIn => type == 'STOCK_IN';
  bool get isStockOut => type == 'STOCK_OUT';
  bool get isAdjustment => type == 'ADJUSTMENT';
}
