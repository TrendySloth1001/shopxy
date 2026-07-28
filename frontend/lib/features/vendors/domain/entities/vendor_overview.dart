/// Aggregated detail payload backing the vendor detail screen.
class VendorOverview {
  const VendorOverview({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.stateCode,
    this.pinCode,
    this.panNumber,
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
    this.balance = 0,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? pinCode;
  final String? panNumber;
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
  /// Outstanding payable in INR. Computed by the backend as
  /// sum(PURCHASE CONFIRMED invoices) − sum(PAYMENT payments). > 0 means
  /// the shop owes the vendor.
  final double balance;

  double get totalPurchases => totals
      .where((t) => t.type == 'PURCHASE')
      .fold(0.0, (sum, t) => sum + t.total);

  double get totalReturns => totals
      .where((t) => t.type == 'PURCHASE_RETURN')
      .fold(0.0, (sum, t) => sum + t.total);

  double get netPurchased => totalPurchases - totalReturns;
}

/// The customer account a vendor is linked to.
///
/// Name only. Same reasoning as [PartyLinkedUser]: the backend selects
/// `{ id, name, avatarUrl }` and withholds the linked account's login email,
/// which belongs to a different data principal. Casting an `email` the server
/// never sends is what threw "type 'Null' is not a subtype of type 'String' in
/// type cast" on any linked vendor.
class VendorLinkedUser {
  const VendorLinkedUser({required this.id, required this.name});
  final String id;
  final String name;
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

  final String id;
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

  final String id;
  final String productId;
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
