class ChallanItem {
  const ChallanItem({
    required this.id,
    required this.challanId,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.quantity,
  });

  final int id;
  final int challanId;
  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  final double quantity;
}

class ChallanInvoiceRef {
  const ChallanInvoiceRef({
    required this.id,
    required this.invoiceNo,
    required this.status,
  });

  final int id;
  final String invoiceNo;
  final String status;
}

class Challan {
  const Challan({
    required this.id,
    required this.challanNo,
    required this.status,
    required this.partyName,
    this.partyPhone,
    this.note,
    this.invoiceId,
    this.invoice,
    required this.items,
    required this.itemCount,
    required this.createdAt,
  });

  final int id;
  final String challanNo;
  final String status;
  final String partyName;
  final String? partyPhone;
  final String? note;
  final int? invoiceId;
  final ChallanInvoiceRef? invoice;
  final List<ChallanItem> items;
  final int itemCount;
  final DateTime createdAt;

  bool get isPending => status == 'PENDING';
  bool get isConverted => status == 'CONVERTED';
  bool get isCancelled => status == 'CANCELLED';
}

class ChallanItemDraft {
  ChallanItemDraft({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    this.quantity = 1.0,
  });

  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  double quantity;
}
