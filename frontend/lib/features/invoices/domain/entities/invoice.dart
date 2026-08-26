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
    this.taxableValue = 0,
    this.igstAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.cessRate = 0,
    this.cessAmount = 0,
  });

  final String id;
  final String invoiceId;
  final String productId;
  final String productName;
  final String productSku;
  final String? hsn;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discount;
  final double total;
  final double taxableValue;
  final double igstAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double cessRate;
  final double cessAmount;
}

class InvoiceVendorRef {
  const InvoiceVendorRef({required this.id, required this.name});
  final String id;
  final String name;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNo,
    required this.type,
    required this.status,
    this.partyId,
    this.vendorId,
    this.vendor,
    this.customerName,
    this.customerPhone,
    this.customerGstin,
    this.customerAddress,
    this.customerCity,
    this.customerState,
    this.customerStateCode,
    this.customerPinCode,
    this.customerPanNumber,
    this.vendorName,
    this.vendorPhone,
    this.vendorGstin,
    this.vendorAddress,
    this.vendorCity,
    this.vendorState,
    this.vendorStateCode,
    this.vendorPinCode,
    this.vendorPanNumber,
    required this.subtotal,
    required this.taxAmount,
    required this.discount,
    required this.total,
    this.taxableValue = 0,
    this.igstAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.cessAmount = 0,
    this.roundOff = 0,
    this.amountInWords,
    this.documentType = 'TAX_INVOICE',
    this.financialYear = '',
    this.placeOfSupplyStateCode,
    this.isInterstate = false,
    this.note,
    required this.invoiceDate,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.itemCount,
  });

  final String id;
  final String invoiceNo;
  final String type;
  final String status;
  final String? partyId;
  final String? vendorId;
  final InvoiceVendorRef? vendor;
  final String? customerName;
  final String? customerPhone;
  final String? customerGstin;
  final String? customerAddress;
  final String? customerCity;
  final String? customerState;
  final String? customerStateCode;
  final String? customerPinCode;
  final String? customerPanNumber;
  final String? vendorName;
  final String? vendorPhone;
  final String? vendorGstin;
  final String? vendorAddress;
  final String? vendorCity;
  final String? vendorState;
  final String? vendorStateCode;
  final String? vendorPinCode;
  final String? vendorPanNumber;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double total;
  final double taxableValue;
  final double igstAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double cessAmount;
  final double roundOff;
  final String? amountInWords;
  final String documentType;
  final String financialYear;
  final String? placeOfSupplyStateCode;
  final bool isInterstate;
  final String? note;
  final DateTime invoiceDate;

  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InvoiceItem> items;
  final int? itemCount;

  bool get isArchived => archivedAt != null;

  bool get isSale => type == 'SALE';
  bool get isPurchase => type == 'PURCHASE';
  bool get isDraft => status == 'DRAFT';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCancelled => status == 'CANCELLED';

  String get partyName =>
      isSale ? (customerName ?? 'Walk-in Customer') : (vendor?.name ?? vendorName ?? 'Unknown Vendor');
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

  factory InvoiceItemDraft.fromInvoiceItem(InvoiceItem item) {
    return InvoiceItemDraft(
      productId: item.productId,
      productName: item.productName,
      productSku: item.productSku,
      hsn: item.hsn,
      unit: item.unit,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxPercent: item.taxPercent,
      discount: item.discount,
    );
  }

  final String productId;
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
