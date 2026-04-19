class InvoiceItem {
  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.productSku,
    this.hsn,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.taxPercent,
    required this.discount,
    required this.total,
  });

  final int id;
  final int invoiceId;
  final int productId;
  final String productName;
  final String productSku;
  final String? hsn;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discount;
  final double total;
}

class InvoiceVendorRef {
  const InvoiceVendorRef({required this.id, required this.name});
  final int id;
  final String name;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNo,
    required this.type,
    required this.status,
    this.vendor,
    this.customerName,
    this.customerPhone,
    this.customerGstin,
    required this.subtotal,
    required this.taxAmount,
    required this.discount,
    required this.total,
    this.note,
    required this.invoiceDate,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.itemCount,
  });

  final int id;
  final String invoiceNo;
  final String type; // SALE | PURCHASE
  final String status; // DRAFT | CONFIRMED | CANCELLED
  final InvoiceVendorRef? vendor;
  final String? customerName;
  final String? customerPhone;
  final String? customerGstin;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double total;
  final String? note;
  final DateTime invoiceDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InvoiceItem> items;
  final int? itemCount;

  bool get isSale => type == 'SALE';
  bool get isPurchase => type == 'PURCHASE';
  bool get isDraft => status == 'DRAFT';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCancelled => status == 'CANCELLED';

  String get partyName =>
      isSale ? (customerName ?? 'Walk-in Customer') : (vendor?.name ?? 'Unknown Vendor');
}

class InvoiceItemDraft {
  InvoiceItemDraft({
    required this.productId,
    required this.productName,
    required this.productSku,
    this.hsn,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.taxPercent = 0,
    this.discount = 0,
  });

  final int productId;
  final String productName;
  final String productSku;
  final String? hsn;
  final String unit;
  double quantity;
  double unitPrice;
  double taxPercent;
  double discount;

  double get subtotal => quantity * unitPrice - discount;
  double get tax => (subtotal * taxPercent) / 100;
  double get total => subtotal + tax;
}
