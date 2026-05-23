/// A money-movement against a party (RECEIPT) or vendor (PAYMENT).
/// Backend assigns the reference no (RCT/FY/00001 or PAY/FY/00001).
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

  final int id;

  /// 'RECEIPT' (money in) or 'PAYMENT' (money out).
  final String type;
  final String referenceNo;
  final double amount;

  /// CASH | UPI | NEFT | RTGS | CHEQUE | CARD | OTHER.
  final String mode;
  final String? modeReference;
  final DateTime paymentDate;
  final int? partyId;
  final String? partyName;
  final int? vendorId;
  final String? vendorName;
  final int? invoiceId;
  final String? invoiceNo;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReceipt => type == 'RECEIPT';
  bool get isPayment => type == 'PAYMENT';
}

/// One row in the party/vendor ledger timeline. Either an invoice debit
/// or a payment credit — the kind switch + running balance is computed
/// server-side so the UI just renders.
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

  /// 'invoice' or 'payment'.
  final String kind;
  final int id;
  final DateTime date;
  final String label;
  final double debit;
  final double credit;
  final double runningBalance;

  // Payment-only fields.
  final String? mode;
  final String? modeReference;
  final String? note;
  final int? invoiceId;

  // Invoice-only fields.
  final String? documentType;
  final String? status;

  bool get isInvoice => kind == 'invoice';
  bool get isPayment => kind == 'payment';
}

/// Aggregated ledger response for one party or vendor.
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
