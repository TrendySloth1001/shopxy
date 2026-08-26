enum ShopRole { party, vendor }

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

  final String id;
  final ShopRole role;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final int invoiceCount;

  final String? shopId;
  final String? shopName;
  final String? shopSlug;
  final String? shopLogoUrl;
  final String? shopBannerUrl;

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
      id: j['id'].toString(),
      role: role,
      name: j['name'] as String,
      email: j['email'] as String?,
      phone: j['phone'] as String?,
      address: j['address'] as String?,
      invoiceCount: (counts?['invoices'] as int?) ?? 0,
      shopId: shop?['id']?.toString(),
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

  final String id;
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
        id: j['id'].toString(),
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

  final String id;
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
        id: j['id'].toString(),
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
      id: j['id'].toString(),
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
      shopName: (isSale ? j['customerName'] : j['vendorName']) as String?,
      shopPhone: (isSale ? j['customerPhone'] : j['vendorPhone']) as String?,
      shopGstin: (isSale ? j['customerGstin'] : j['vendorGstin']) as String?,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => ShopInvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

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

  final String id;
  final String quotationNo;
  final String status;
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

  bool get isRequested => status == 'REQUESTED';

  factory ShopQuotation.fromJson(Map<String, dynamic> j) {
    final invoice = j['invoice'] as Map<String, dynamic>?;
    return ShopQuotation(
      id: j['id'].toString(),
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
