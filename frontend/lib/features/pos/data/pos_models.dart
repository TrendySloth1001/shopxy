class SaleSnapshot {
  SaleSnapshot({
    required this.saleId,
    required this.status,
    required this.version,
    required this.invoiceId,
    required this.headerDiscount,
    required this.lines,
    required this.totals,
  });

  final String saleId;
  final String status;
  final int version;
  final String? invoiceId;
  final double headerDiscount;
  final List<SaleLine> lines;
  final SaleTotals totals;

  factory SaleSnapshot.fromJson(Map<String, dynamic> json) {
    final sale = json['sale'] as Map<String, dynamic>;
    return SaleSnapshot(
      saleId: sale['id'].toString(),
      status: sale['status'] as String,
      version: sale['version'] as int,
      invoiceId: sale['invoiceId']?.toString(),
      headerDiscount: _d(sale['headerDiscount']),
      lines: (json['lines'] as List)
          .map((e) => SaleLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: SaleTotals.fromJson(json['totals'] as Map<String, dynamic>),
    );
  }
}

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

class SaleLine {
  SaleLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineDiscount,
    required this.total,
  });

  final String productId;
  final String name;
  final String sku;
  final String? imageUrl;
  final double quantity;
  final double unitPrice;
  final double lineDiscount;
  final double total;

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
        productId: json['productId'].toString(),
        name: json['name'] as String,
        sku: json['sku'] as String,
        imageUrl: json['imageUrl'] as String?,
        quantity: _d(json['quantity']),
        unitPrice: _d(json['unitPrice']),
        lineDiscount: _d(json['lineDiscount']),
        total: _d(json['total']),
      );
}

class SaleTotals {
  SaleTotals({
    required this.itemCount,
    required this.taxableValue,
    required this.taxAmount,
    required this.total,
  });

  final double itemCount;
  final double taxableValue;
  final double taxAmount;
  final double total;

  factory SaleTotals.fromJson(Map<String, dynamic> json) => SaleTotals(
        itemCount: _d(json['itemCount']),
        taxableValue: _d(json['taxableValue']),
        taxAmount: _d(json['taxAmount']),
        total: _d(json['total']),
      );
}
