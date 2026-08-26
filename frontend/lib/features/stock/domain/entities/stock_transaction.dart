class StockTransaction {
  const StockTransaction({
    required this.id,
    required this.productId,
    required this.type,
    required this.direction,
    required this.reasonCode,
    required this.sourceType,
    this.sourceId,
    this.sourceLineId,
    required this.quantity,
    this.unitPrice,
    this.unitCost,
    this.totalValue,
    this.stockBefore,
    this.stockAfter,
    this.supplierName,
    this.vendorId,
    this.vendorName,
    this.purchasePriceMode,
    this.purchasePriceBefore,
    this.purchasePriceAfter,
    this.reversesId,
    this.createdById,
    this.createdByName,
    this.note,
    this.productName,
    this.productSku,
    this.productUnit,
    required this.createdAt,
  });

  final String id;
  final String productId;

  final String type;

  final String direction;

  final String reasonCode;

  final String sourceType;

  final String? sourceId;
  final String? sourceLineId;

  final double quantity;

  final double? unitPrice;

  final double? unitCost;

  final double? totalValue;

  final double? stockBefore;
  final double? stockAfter;

  final String? supplierName;
  final String? vendorId;
  final String? vendorName;
  final String? purchasePriceMode;
  final double? purchasePriceBefore;
  final double? purchasePriceAfter;

  final String? reversesId;

  final String? createdById;
  final String? createdByName;

  final String? note;
  final String? productName;
  final String? productSku;
  final String? productUnit;
  final DateTime createdAt;

  String? get displaySupplier => vendorName ?? supplierName;

  bool get isStockIn => direction == 'IN';
  bool get isStockOut => direction == 'OUT';
  bool get isReversal => reversesId != null;

  bool get hasSourceDocument =>
      sourceId != null && sourceType != 'MANUAL' && sourceType != 'OPENING';
}

String reasonCodeLabel(String code) {
  switch (code) {
    case 'SALE':
      return 'Sale';
    case 'PURCHASE':
      return 'Purchase';
    case 'OPENING':
      return 'Opening balance';
    case 'DAMAGE':
      return 'Damaged';
    case 'EXPIRED':
      return 'Expired';
    case 'SHRINKAGE':
      return 'Shrinkage';
    case 'RECOUNT':
      return 'Recount correction';
    case 'RETURN_IN':
      return 'Customer return';
    case 'RETURN_OUT':
      return 'Return to vendor';
    default:
      return code;
  }
}

String sourceTypeLabel(String code) {
  switch (code) {
    case 'INVOICE':
      return 'Invoice';
    case 'CHALLAN':
      return 'Challan';
    case 'ADJUSTMENT':
      return 'Adjustment';
    case 'OPENING':
      return 'Opening';
    case 'MANUAL':
    default:
      return 'Manual';
  }
}
