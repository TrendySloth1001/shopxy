import 'package:shopxy/features/payments/domain/entities/payment.dart';

class PaymentDto {
  /// Prisma `Decimal` columns serialize to JSON as strings — funnel every
  /// money/quantity field through this so we never cast a String to num.
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static Payment fromJson(Map<String, dynamic> json) {
    final party = json['party'] as Map<String, dynamic>?;
    final vendor = json['vendor'] as Map<String, dynamic>?;
    final invoice = json['invoice'] as Map<String, dynamic>?;
    return Payment(
      id: json['id'] as int,
      type: json['type'] as String,
      referenceNo: json['referenceNo'] as String,
      amount: _d(json['amount']),
      mode: json['mode'] as String,
      modeReference: json['modeReference'] as String?,
      paymentDate: DateTime.parse(json['paymentDate'] as String),
      partyId: json['partyId'] as int?,
      partyName: party == null ? null : party['name'] as String?,
      vendorId: json['vendorId'] as int?,
      vendorName: vendor == null ? null : vendor['name'] as String?,
      invoiceId: json['invoiceId'] as int?,
      invoiceNo: invoice == null ? null : invoice['invoiceNo'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Ledger ledgerFromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? const [])
        .map((e) => _ledgerEntryFromJson(e as Map<String, dynamic>))
        .toList();
    return Ledger(
      balance: _d(json['balance']),
      openingBalance: _d(json['openingBalance']),
      entries: entries,
    );
  }

  static LedgerEntry _ledgerEntryFromJson(Map<String, dynamic> j) {
    return LedgerEntry(
      kind: j['kind'] as String,
      id: j['id'] as int,
      date: DateTime.parse(j['date'] as String),
      label: j['label'] as String,
      debit: _d(j['debit']),
      credit: _d(j['credit']),
      runningBalance: _d(j['runningBalance']),
      mode: j['mode'] as String?,
      modeReference: j['modeReference'] as String?,
      note: j['note'] as String?,
      invoiceId: j['invoiceId'] as int?,
      documentType: j['documentType'] as String?,
      status: j['status'] as String?,
    );
  }
}
