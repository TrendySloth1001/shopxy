/// Aggregated detail payload backing the vendor detail screen.
class VendorOverview {
  const VendorOverview({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.linkedUser,
    required this.invoiceCount,
    required this.stockInCount,
    required this.totals,
    required this.recentInvoices,
    required this.recentStockIns,
    this.lastActivityAt,
  });

  final int id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VendorLinkedUser? linkedUser;
  final int invoiceCount;
  final int stockInCount;
  final List<VendorTotal> totals;
  final List<VendorInvoiceRef> recentInvoices;
  final List<VendorStockInRef> recentStockIns;
  final DateTime? lastActivityAt;

  double get totalPurchases => totals
      .where((t) => t.type == 'PURCHASE')
      .fold(0.0, (sum, t) => sum + t.total);

  double get totalReturns => totals
      .where((t) => t.type == 'PURCHASE_RETURN')
      .fold(0.0, (sum, t) => sum + t.total);

  double get netPurchased => totalPurchases - totalReturns;
}

class VendorLinkedUser {
  const VendorLinkedUser({required this.id, required this.name, required this.email});
  final int id;
  final String name;
  final String email;
}

class VendorTotal {
  const VendorTotal({required this.type, required this.count, required this.total});
  final String type;
  final int count;
  final double total;
}

class VendorInvoiceRef {
  const VendorInvoiceRef({
    required this.id,
    required this.invoiceNo,
    required this.type,
    required this.status,
    required this.invoiceDate,
    required this.total,
    required this.itemCount,
  });

  final int id;
  final String invoiceNo;
  final String type;
  final String status;
  final DateTime invoiceDate;
  final double total;
  final int itemCount;
}

class VendorStockInRef {
  const VendorStockInRef({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.quantity,
    this.unitCost,
    this.totalValue,
    required this.createdAt,
    required this.reasonCode,
    required this.sourceType,
  });

  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
  final double? unitCost;
  final double? totalValue;
  final DateTime createdAt;
  final String reasonCode;
  final String sourceType;
}
