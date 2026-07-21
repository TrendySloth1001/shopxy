/// Drill-down data behind the Receivables / Payables KPI cards — a faithful
/// port of merchant-web's `features/dashboard/drilldown.ts`. Each breakdown
/// lists debtors/creditors (biggest balance first) with the confirmed
/// documents behind the balance. Backs `GET /dashboard/receivables` and
/// `GET /dashboard/payables` (`dashboard.service.assembleBreakdown`).
library;

/// Coerce a JSON money value (may arrive as a number or a numeric string)
/// to a double, defaulting to 0 — mirrors the web schema's `z.coerce.number`.
double _money(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class BreakdownInvoice {
  const BreakdownInvoice({
    required this.id,
    required this.invoiceNo,
    required this.documentType,
    required this.invoiceDate,
    required this.total,
  });

  final int id;
  final String invoiceNo;
  final String documentType;
  final String invoiceDate; // ISO string
  final double total;

  factory BreakdownInvoice.fromJson(Map<String, dynamic> j) => BreakdownInvoice(
        id: (j['id'] as num).toInt(),
        invoiceNo: j['invoiceNo']?.toString() ?? '',
        documentType: j['documentType']?.toString() ?? 'TAX_INVOICE',
        invoiceDate: j['invoiceDate']?.toString() ?? '',
        total: _money(j['total']),
      );
}

class BreakdownParty {
  const BreakdownParty({
    required this.id,
    required this.name,
    required this.billed,
    required this.received,
    required this.paid,
    required this.outstanding,
    required this.invoices,
  });

  final int id;
  final String name;
  final double billed;

  /// Settled amount is named `received` on the receivables side and `paid`
  /// on the payables side — only one is present per row.
  final double? received;
  final double? paid;
  final double outstanding;
  final List<BreakdownInvoice> invoices;

  /// The amount already settled against this counterparty, whichever side.
  double get settled => received ?? paid ?? 0;

  factory BreakdownParty.fromJson(Map<String, dynamic> j) => BreakdownParty(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        billed: _money(j['billed']),
        received: j.containsKey('received') ? _money(j['received']) : null,
        paid: j.containsKey('paid') ? _money(j['paid']) : null,
        outstanding: _money(j['outstanding']),
        invoices: ((j['invoices'] as List?) ?? const [])
            .map((e) => BreakdownInvoice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class KpiBreakdown {
  const KpiBreakdown({
    required this.outstanding,
    required this.count,
    required this.parties,
  });

  final double outstanding;
  final int count;
  final List<BreakdownParty> parties;

  factory KpiBreakdown.fromJson(Map<String, dynamic> j) => KpiBreakdown(
        outstanding: _money(j['outstanding']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        parties: ((j['parties'] as List?) ?? const [])
            .map((e) => BreakdownParty.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
