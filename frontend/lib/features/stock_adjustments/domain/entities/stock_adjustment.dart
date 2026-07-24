class StockAdjustmentItem {
  const StockAdjustmentItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.quantity,
    this.unitCost,
    this.note,
  });

  final String id;
  final String productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double? unitCost;
  final String? note;
}

class StockAdjustment {
  const StockAdjustment({
    required this.id,
    required this.adjustmentNo,
    required this.reasonCode,
    required this.direction,
    this.note,
    this.createdByName,
    required this.createdAt,
    this.items = const [],
    this.itemCount,
  });

  final String id;
  final String adjustmentNo;
  final String reasonCode;
  final String direction;
  final String? note;
  final String? createdByName;
  final DateTime createdAt;
  final List<StockAdjustmentItem> items;
  final int? itemCount;
}
