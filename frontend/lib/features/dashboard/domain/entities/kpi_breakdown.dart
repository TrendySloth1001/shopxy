library;

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

  final String id;
  final String invoiceNo;
  final String documentType;
  final String invoiceDate;
  final double total;

  factory BreakdownInvoice.fromJson(Map<String, dynamic> j) => BreakdownInvoice(
        id: j['id'].toString(),
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

  final String id;
  final String name;
  final double billed;

  final double? received;
  final double? paid;
  final double outstanding;
  final List<BreakdownInvoice> invoices;

  double get settled => received ?? paid ?? 0;

  factory BreakdownParty.fromJson(Map<String, dynamic> j) => BreakdownParty(
        id: j['id'].toString(),
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
