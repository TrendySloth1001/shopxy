class Payment {
  const Payment({
    required this.id,
    required this.type,
    required this.referenceNo,
    required this.amount,
    required this.mode,
    this.modeReference,
    required this.paymentDate,
    this.partyId,
    this.partyName,
    this.vendorId,
    this.vendorName,
    this.invoiceId,
    this.invoiceNo,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  final String type;
  final String referenceNo;
  final double amount;

  final String mode;
  final String? modeReference;
  final DateTime paymentDate;
  final String? partyId;
  final String? partyName;
  final String? vendorId;
  final String? vendorName;
  final String? invoiceId;
  final String? invoiceNo;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReceipt => type == 'RECEIPT';
  bool get isPayment => type == 'PAYMENT';
}

class LedgerEntry {
  const LedgerEntry({
    required this.kind,
    required this.id,
    required this.date,
    required this.label,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.mode,
    this.modeReference,
    this.note,
    this.invoiceId,
    this.documentType,
    this.status,
  });

  final String kind;
  final String id;
  final DateTime date;
  final String label;
  final double debit;
  final double credit;
  final double runningBalance;

  final String? mode;
  final String? modeReference;
  final String? note;
  final String? invoiceId;

  final String? documentType;
  final String? status;

  bool get isInvoice => kind == 'invoice';
  bool get isPayment => kind == 'payment';
}

class Ledger {
  const Ledger({
    required this.balance,
    required this.openingBalance,
    required this.entries,
  });

  final double balance;
  final double openingBalance;
  final List<LedgerEntry> entries;
}
