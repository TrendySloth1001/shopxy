/// A single immutable row in the stock ledger.
///
/// Every inventory movement (manual stock-in/out, invoice line, challan
/// line, adjustment line, opening balance) is one of these. Direction +
/// reasonCode + sourceType tell the audit story; stockBefore/stockAfter
/// let the ledger be replayed.
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

  /// Legacy three-state column ('STOCK_IN' | 'STOCK_OUT' | 'ADJUSTMENT').
  /// New code should prefer [direction] + [reasonCode].
  final String type;

  /// 'IN' or 'OUT' — the side of the ledger this entry posts on.
  final String direction;

  /// Why this movement happened. One of SALE, PURCHASE, OPENING, DAMAGE,
  /// EXPIRED, SHRINKAGE, RECOUNT, RETURN_IN, RETURN_OUT.
  final String reasonCode;

  /// What document caused the posting: MANUAL, INVOICE, CHALLAN,
  /// ADJUSTMENT, OPENING.
  final String sourceType;

  /// Id of the source document (invoice id, challan id, etc.). Null for
  /// MANUAL / OPENING.
  final String? sourceId;
  final String? sourceLineId;

  /// Always positive — direction carries the sign.
  final double quantity;

  /// Legacy field: stock-in unit price / stock-out optional override.
  final double? unitPrice;

  /// Cost basis at the moment of the movement. For IN: cost of goods
  /// arriving. For OUT: weighted-average cost of consumed FIFO layers.
  final double? unitCost;

  /// qty × unitCost.
  final double? totalValue;

  /// Snapshot of product.stockQuantity immediately before this posting.
  final double? stockBefore;
  final double? stockAfter;

  final String? supplierName;
  final String? vendorId;
  final String? vendorName;
  final String? purchasePriceMode;
  final double? purchasePriceBefore;
  final double? purchasePriceAfter;

  /// If non-null, this row is a reversal of an earlier one.
  final String? reversesId;

  final String? createdById;
  final String? createdByName;

  final String? note;
  final String? productName;
  final String? productSku;
  final String? productUnit;
  final DateTime createdAt;

  /// Display name for the supplier: structured vendor name takes priority.
  String? get displaySupplier => vendorName ?? supplierName;

  bool get isStockIn => direction == 'IN';
  bool get isStockOut => direction == 'OUT';
  bool get isReversal => reversesId != null;

  /// True when the row was posted by an invoice/challan/adjustment
  /// rather than a manual sheet — useful for routing the source link.
  bool get hasSourceDocument =>
      sourceId != null && sourceType != 'MANUAL' && sourceType != 'OPENING';
}

/// Human-readable label for a reason code. Kept here so UI widgets
/// don't have to switch on raw strings.
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

/// Human-readable label for the source document type.
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
