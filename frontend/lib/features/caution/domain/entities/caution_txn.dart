/// One row in a party's caution / security-deposit ledger.
///
/// * DEPOSIT    — money taken in (increases the held balance).
/// * REFUND     — money paid back (decreases the balance).
/// * ADJUSTMENT — deposit set off against an invoice (decreases the
///                balance; [invoiceNo] names the bill it was applied to).
/// * FORFEIT    — deposit kept on the party's default (decreases the
///                balance; taxable business income, see [gstTreatment]).
class CautionTxn {
  const CautionTxn({
    required this.id,
    required this.type,
    required this.amount,
    this.mode,
    this.modeReference,
    this.receiptNo,
    this.gstTreatment,
    this.note,
    required this.createdAt,
    this.invoiceId,
    this.invoiceNo,
  });

  final int id;
  final String type;
  final double amount;
  final String? mode;
  final String? modeReference;
  /// Ordinary money-receipt number on DEPOSIT/REFUND (e.g. CAU/25-26/00001).
  final String? receiptNo;
  /// FORFEIT only: 'NONE' (no GST) | 'SUPPLY' (GST at goods rate).
  final String? gstTreatment;
  final String? note;
  final DateTime createdAt;
  final int? invoiceId;
  final String? invoiceNo;

  bool get isDeposit => type == 'DEPOSIT';
  bool get isRefund => type == 'REFUND';
  bool get isAdjustment => type == 'ADJUSTMENT';
  bool get isForfeit => type == 'FORFEIT';

  /// Deposits add to the held balance; refunds, set-offs and forfeits subtract.
  bool get increasesBalance => isDeposit;
}

/// A party-initiated caution request the merchant reviews. PENDING ones can be
/// approved (→ a confirmed DEPOSIT) or rejected.
class CautionRequest {
  const CautionRequest({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.amount,
    this.mode,
    this.modeReference,
    this.note,
    required this.status,
    this.reviewNote,
    required this.createdAt,
    this.basket = const [],
    this.basketValue,
  });

  final int id;
  final int partyId;
  final String partyName;
  final double amount;
  final String? mode;
  final String? modeReference;
  final String? note;
  final String status; // PENDING | APPROVED | REJECTED | CANCELLED
  final String? reviewNote;
  final DateTime createdAt;

  /// Read-only basket the customer browsed to justify/size the deposit.
  /// Context only — the approved deposit is NOT earmarked to these goods.
  final List<CautionBasketLine> basket;
  final double? basketValue;

  bool get hasBasket => basket.isNotEmpty;
  bool get isPending => status == 'PENDING';
}

/// One line in a caution request's context basket.
class CautionBasketLine {
  const CautionBasketLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.sku,
  });
  final String name;
  final double qty;
  final double unitPrice;
  final double lineTotal;
  final String? sku;
}

/// The caution ledger for a party: the current held balance plus a page of
/// history (most recent first).
class CautionHistory {
  const CautionHistory({required this.balance, required this.entries});
  final double balance;
  final List<CautionTxn> entries;
}
