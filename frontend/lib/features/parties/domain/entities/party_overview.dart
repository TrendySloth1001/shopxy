/// Aggregated detail payload backing the party detail screen.
/// Counts and totals are pre-computed server-side so the page only
/// pays one round trip.
class PartyOverview {
  const PartyOverview({
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
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    this.linkedUser,
    required this.invoiceCount,
    required this.challanCount,
    required this.totals,
    required this.recentInvoices,
    required this.recentChallans,
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
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PartyLinkedUser? linkedUser;
  final int invoiceCount;
  final int challanCount;
  final List<PartyTotal> totals;
  final List<PartyInvoiceRef> recentInvoices;
  final List<PartyChallanRef> recentChallans;
  final DateTime? lastActivityAt;
  /// Current outstanding receivable in INR. Computed by the backend as
  /// sum(SALE CONFIRMED invoices) − sum(RECEIPT payments). > 0 means the
  /// party owes the shop; < 0 means the shop owes them (advance/credit).
  final double balance;

  double get totalSales => totals
      .where((t) => t.type == 'SALE')
      .fold(0.0, (sum, t) => sum + t.total);

  double get totalReturns => totals
      .where((t) => t.type == 'SALES_RETURN')
      .fold(0.0, (sum, t) => sum + t.total);

  double get netBilled => totalSales - totalReturns;
}

class PartyLinkedUser {
  const PartyLinkedUser({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;
}

class PartyTotal {
  const PartyTotal({required this.type, required this.count, required this.total});
  final String type;
  final int count;
  final double total;
}

class PartyInvoiceRef {
  const PartyInvoiceRef({
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

  bool get isSale => type == 'SALE';
}

class PartyChallanRef {
  const PartyChallanRef({
    required this.id,
    required this.challanNo,
    required this.status,
    required this.createdAt,
    required this.itemCount,
    this.invoiceId,
  });

  final String id;
  final String challanNo;
  final String status;
  final DateTime createdAt;
  final int itemCount;
  final String? invoiceId;
}
