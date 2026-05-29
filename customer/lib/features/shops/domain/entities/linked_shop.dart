enum ShopRole { party, vendor }

/// Prisma's `Decimal` columns serialize to JSON as **strings**
/// (e.g. `"1500.00"`), not numbers. Treating them as `num` in a cast
/// throws a `String is not a subtype of num` at runtime, so every
/// money / quantity field comes through this helper.
double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class LinkedShop {
  const LinkedShop({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.invoiceCount,
    this.shopId,
    this.shopName,
    this.shopSlug,
    this.shopLogoUrl,
    this.shopBannerUrl,
    this.lastInvoiceAt,
    this.lastInvoiceTotal,
  });

  /// `partyId` or `vendorId` from the merchant's database, depending on
  /// [role]. Customer-side routes use this id to fetch invoices.
  final int id;
  final ShopRole role;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final int invoiceCount;

  /// Owning shop's identity. Joined from `party.shop` / `vendor.shop`
  /// server-side so we can render real shop branding instead of an
  /// initial chip. All nullable so legacy payloads still parse.
  final int? shopId;
  final String? shopName;
  final String? shopSlug;
  final String? shopLogoUrl;
  final String? shopBannerUrl;

  /// Most recent invoice activity on this link — sorted-by + labelled
  /// on the Merchants tab so live relationships float to the top.
  final DateTime? lastInvoiceAt;
  final double? lastInvoiceTotal;

  factory LinkedShop.fromJson(Map<String, dynamic> j, ShopRole role) {
    final counts = j['_count'] as Map<String, dynamic>?;
    final shop = j['shop'] as Map<String, dynamic>?;
    final invoices = j['invoices'] as List<dynamic>?;
    final lastInvoice = (invoices != null && invoices.isNotEmpty)
        ? invoices.first as Map<String, dynamic>
        : null;
    return LinkedShop(
      id: j['id'] as int,
      role: role,
      name: j['name'] as String,
      email: j['email'] as String?,
      phone: j['phone'] as String?,
      address: j['address'] as String?,
      invoiceCount: (counts?['invoices'] as int?) ?? 0,
      shopId: shop?['id'] as int?,
      shopName: shop?['name'] as String?,
      shopSlug: shop?['slug'] as String?,
      shopLogoUrl: shop?['logoUrl'] as String?,
      shopBannerUrl: shop?['bannerUrl'] as String?,
      lastInvoiceAt: lastInvoice?['invoiceDate'] == null
          ? null
          : DateTime.parse(lastInvoice!['invoiceDate'] as String),
      lastInvoiceTotal: lastInvoice == null
          ? null
          : _asDouble(lastInvoice['total']),
    );
  }
}

class ShopInvoice {
  const ShopInvoice({
    required this.id,
    required this.invoiceNo,
    required this.type,
    required this.status,
    required this.invoiceDate,
    required this.subtotal,
    required this.taxAmount,
    required this.discount,
    required this.total,
    required this.itemCount,
  });

  final int id;
  final String invoiceNo;
  final String type;
  final String status;
  final DateTime invoiceDate;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double total;
  final int itemCount;

  bool get isSale => type == 'SALE';

  factory ShopInvoice.fromJson(Map<String, dynamic> j) => ShopInvoice(
        id: j['id'] as int,
        invoiceNo: j['invoiceNo'] as String,
        type: j['type'] as String,
        status: j['status'] as String,
        invoiceDate: DateTime.parse(j['invoiceDate'] as String),
        subtotal: _asDouble(j['subtotal']),
        taxAmount: _asDouble(j['taxAmount']),
        discount: _asDouble(j['discount']),
        total: _asDouble(j['total']),
        itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      );
}

class ShopInvoiceItem {
  const ShopInvoiceItem({
    required this.id,
    required this.productName,
    required this.productSku,
    required this.hsn,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    required this.discount,
    required this.total,
  });

  final int id;
  final String productName;
  final String productSku;
  final String? hsn;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discount;
  final double total;

  factory ShopInvoiceItem.fromJson(Map<String, dynamic> j) => ShopInvoiceItem(
        id: j['id'] as int,
        productName: j['productName'] as String,
        productSku: j['productSku'] as String,
        hsn: j['hsn'] as String?,
        unit: j['unit'] as String,
        quantity: _asDouble(j['quantity']),
        unitPrice: _asDouble(j['unitPrice']),
        taxPercent: _asDouble(j['taxPercent']),
        discount: _asDouble(j['discount']),
        total: _asDouble(j['total']),
      );
}

class ShopInvoiceDetail extends ShopInvoice {
  ShopInvoiceDetail({
    required super.id,
    required super.invoiceNo,
    required super.type,
    required super.status,
    required super.invoiceDate,
    required super.subtotal,
    required super.taxAmount,
    required super.discount,
    required super.total,
    required super.itemCount,
    required this.note,
    required this.shopName,
    required this.shopPhone,
    required this.shopGstin,
    required this.items,
  });

  final String? note;
  final String? shopName;
  final String? shopPhone;
  final String? shopGstin;
  final List<ShopInvoiceItem> items;

  factory ShopInvoiceDetail.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String;
    final isSale = type == 'SALE';
    return ShopInvoiceDetail(
      id: j['id'] as int,
      invoiceNo: j['invoiceNo'] as String,
      type: type,
      status: j['status'] as String,
      invoiceDate: DateTime.parse(j['invoiceDate'] as String),
      subtotal: _asDouble(j['subtotal']),
      taxAmount: _asDouble(j['taxAmount']),
      discount: _asDouble(j['discount']),
      total: _asDouble(j['total']),
      itemCount: ((j['items'] as List?)?.length) ?? 0,
      note: j['note'] as String?,
      // For SALE, the "issuing shop" identity is on the customer-* fields
      // (the merchant always fills them with their own party data); for
      // PURCHASE the shop's identity is on the vendor-* fields.
      shopName: (isSale ? j['customerName'] : j['vendorName']) as String?,
      shopPhone: (isSale ? j['customerPhone'] : j['vendorPhone']) as String?,
      shopGstin: (isSale ? j['customerGstin'] : j['vendorGstin']) as String?,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => ShopInvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One row in the caution / security-deposit ledger a shop holds against
/// this customer. Read-only on the customer side.
class ShopCautionTxn {
  const ShopCautionTxn({
    required this.id,
    required this.type,
    required this.amount,
    this.mode,
    this.note,
    required this.createdAt,
    this.invoiceNo,
    this.receiptNo,
  });

  final int id;
  final String type; // DEPOSIT | REFUND | ADJUSTMENT | FORFEIT
  final double amount;
  final String? mode;
  final String? note;
  final DateTime createdAt;
  final String? invoiceNo;
  final String? receiptNo;

  bool get isDeposit => type == 'DEPOSIT';
  bool get isAdjustment => type == 'ADJUSTMENT';
  bool get isForfeit => type == 'FORFEIT';

  /// Deposits add to what the shop holds; refunds, set-offs and forfeits
  /// reduce it.
  bool get increasesHeld => isDeposit;

  factory ShopCautionTxn.fromJson(Map<String, dynamic> j) => ShopCautionTxn(
        id: j['id'] as int,
        type: j['type'] as String,
        amount: _asDouble(j['amount']),
        mode: j['mode'] as String?,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        invoiceNo: j['invoiceNo'] as String?,
        receiptNo: j['receiptNo'] as String?,
      );
}

/// A caution deposit the customer has *offered* to post to the shop, awaiting
/// the merchant's approval. Distinct from a `ShopCautionTxn` (which is money
/// the shop already holds) — a request only becomes a deposit once approved.
class ShopCautionRequest {
  const ShopCautionRequest({
    required this.id,
    required this.amount,
    this.mode,
    this.modeReference,
    this.note,
    required this.status,
    this.reviewNote,
    required this.createdAt,
    this.basketValue,
    this.basketCount = 0,
  });

  final int id;
  final double amount;
  final String? mode;
  final String? modeReference;
  final String? note;
  final String status; // PENDING | APPROVED | REJECTED | CANCELLED
  final String? reviewNote;
  final DateTime createdAt;

  /// Intended-purchase value of the basket the customer browsed (context).
  final double? basketValue;
  final int basketCount;

  bool get hasBasket => basketCount > 0;
  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  factory ShopCautionRequest.fromJson(Map<String, dynamic> j) {
    final basket = j['basket'] as List<dynamic>?;
    return ShopCautionRequest(
      id: j['id'] as int,
      amount: _asDouble(j['amount']),
      mode: j['mode'] as String?,
      modeReference: j['modeReference'] as String?,
      note: j['note'] as String?,
      status: j['status'] as String,
      reviewNote: j['reviewNote'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      basketValue: j['basketValue'] == null ? null : _asDouble(j['basketValue']),
      basketCount: basket?.length ?? 0,
    );
  }
}

/// The caution ledger for one linked shop: how much the shop currently
/// holds plus the most-recent-first history.
class ShopCautionLedger {
  const ShopCautionLedger({required this.balance, required this.entries});
  final double balance;
  final List<ShopCautionTxn> entries;
}

/// One line in a quotation the shop sent this customer.
class ShopQuotationLine {
  const ShopQuotationLine({
    required this.name,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    required this.lineTotal,
    this.imageUrl,
  });

  final String name;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double lineTotal;
  final String? imageUrl;

  factory ShopQuotationLine.fromJson(Map<String, dynamic> j) => ShopQuotationLine(
        name: (j['name'] as String?) ?? 'Item',
        sku: j['sku'] as String?,
        quantity: _asDouble(j['quantity']),
        unitPrice: _asDouble(j['unitPrice']),
        taxPercent: _asDouble(j['taxPercent']),
        lineTotal: _asDouble(j['lineTotal']),
        imageUrl: (j['imageUrl'] as String?)?.isNotEmpty == true
            ? j['imageUrl'] as String
            : null,
      );
}

/// A priced quotation the shop sent the customer to accept or decline. On
/// accept it becomes a confirmed invoice in the customer's ledger.
class ShopQuotation {
  const ShopQuotation({
    required this.id,
    required this.quotationNo,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.items,
    required this.createdAt,
    this.note,
    this.declineNote,
    this.invoiceNo,
    this.respondedAt,
  });

  final int id;
  final String quotationNo;
  final String status; // REQUESTED | PENDING | ACCEPTED | DECLINED | CANCELLED | EXPIRED
  final double subtotal;
  final double taxAmount;
  final double total;
  final List<ShopQuotationLine> items;
  final DateTime createdAt;
  final String? note;
  final String? declineNote;
  final String? invoiceNo;
  final DateTime? respondedAt;

  int get itemCount => items.fold(0, (s, l) => s + l.quantity.round());

  bool get isPending => status == 'PENDING';

  /// Customer-built quote still awaiting the shop's pricing — the customer can
  /// withdraw it but can't accept it yet.
  bool get isRequested => status == 'REQUESTED';

  factory ShopQuotation.fromJson(Map<String, dynamic> j) {
    final invoice = j['invoice'] as Map<String, dynamic>?;
    return ShopQuotation(
      id: j['id'] as int,
      quotationNo: j['quotationNo'] as String,
      status: j['status'] as String,
      subtotal: _asDouble(j['subtotal']),
      taxAmount: _asDouble(j['taxAmount']),
      total: _asDouble(j['total']),
      items: (j['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopQuotationLine.fromJson)
          .toList(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      note: j['note'] as String?,
      declineNote: j['declineNote'] as String?,
      invoiceNo: invoice?['invoiceNo'] as String?,
      respondedAt: j['respondedAt'] == null
          ? null
          : DateTime.parse(j['respondedAt'] as String),
    );
  }
}
