class ProductDraft {
  const ProductDraft({
    this.name,
    this.description,
    this.sku,
    this.barcode,
    this.hsnCode,
    this.mrp,
    this.sellingPrice,
    this.purchasePrice,
    this.taxPercent,
    this.stockQuantity,
    this.lowStockThreshold,
    this.unit,
    this.categoryId,
  });

  final String? name;
  final String? description;
  final String? sku;
  final String? barcode;
  final String? hsnCode;
  final double? mrp;
  final double? sellingPrice;
  final double? purchasePrice;
  final double? taxPercent;
  final double? stockQuantity;
  final double? lowStockThreshold;
  final String? unit;
  final int? categoryId;

  bool get hasAnyValue {
    return (name?.trim().isNotEmpty ?? false) ||
        (description?.trim().isNotEmpty ?? false) ||
        (sku?.trim().isNotEmpty ?? false) ||
        (barcode?.trim().isNotEmpty ?? false) ||
        (hsnCode?.trim().isNotEmpty ?? false) ||
        mrp != null ||
        sellingPrice != null ||
        purchasePrice != null ||
        taxPercent != null ||
        stockQuantity != null ||
        lowStockThreshold != null ||
        (unit?.trim().isNotEmpty ?? false) ||
        categoryId != null;
  }
}
