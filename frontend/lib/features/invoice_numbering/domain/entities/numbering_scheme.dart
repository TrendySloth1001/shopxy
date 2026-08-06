/// The 7 document series that carry independently customizable numbering —
/// mirrors the backend's `Series` union (`backend/src/shared/numbering/
/// sequences.ts`) exactly. `PURCHASE_INVOICE`/`CREDIT_NOTE`/`DEBIT_NOTE`
/// stay distinct from `SALE_INVOICE` even though they're all "invoices" —
/// this is the same grouping the backend already used before numbering
/// became customizable.
enum NumberingSeries {
  saleInvoice,
  purchaseInvoice,
  estimate,
  creditNote,
  debitNote,
  challan,
  quotation,
}

extension NumberingSeriesWire on NumberingSeries {
  /// The wire value the backend expects/returns.
  String get wire => switch (this) {
    NumberingSeries.saleInvoice => 'SALE_INVOICE',
    NumberingSeries.purchaseInvoice => 'PURCHASE_INVOICE',
    NumberingSeries.estimate => 'ESTIMATE',
    NumberingSeries.creditNote => 'CREDIT_NOTE',
    NumberingSeries.debitNote => 'DEBIT_NOTE',
    NumberingSeries.challan => 'CHALLAN',
    NumberingSeries.quotation => 'QUOTATION',
  };

  static NumberingSeries fromWire(String s) => switch (s) {
    'SALE_INVOICE' => NumberingSeries.saleInvoice,
    'PURCHASE_INVOICE' => NumberingSeries.purchaseInvoice,
    'ESTIMATE' => NumberingSeries.estimate,
    'CREDIT_NOTE' => NumberingSeries.creditNote,
    'DEBIT_NOTE' => NumberingSeries.debitNote,
    'CHALLAN' => NumberingSeries.challan,
    'QUOTATION' => NumberingSeries.quotation,
    _ => throw ArgumentError('Unknown numbering series: $s'),
  };
}

/// A shop's numbering configuration for one series — mirrors the backend's
/// `SchemeDto` (`backend/src/modules/numbering/numbering.service.ts`).
class NumberingScheme {
  const NumberingScheme({
    required this.series,
    required this.prefix,
    required this.suffix,
    required this.separator,
    required this.padding,
    required this.resetYearly,
    required this.isCustom,
    required this.nextPreview,
    required this.nextSeq,
    required this.financialYear,
  });

  final NumberingSeries series;
  final String prefix;
  final String suffix;
  final String separator;
  final int padding;
  final bool resetYearly;

  /// Whether this shop has a saved override, or is still on the system
  /// default.
  final bool isCustom;

  /// What the next document in this series would look like right now.
  final String nextPreview;

  /// The raw parts behind [nextPreview] — lets the editor recompute the
  /// preview locally as the merchant edits fields, via [formatDocNoPreview].
  final int nextSeq;
  final String financialYear;

  factory NumberingScheme.fromJson(Map<String, dynamic> j) => NumberingScheme(
    series: NumberingSeriesWire.fromWire(j['series'] as String),
    prefix: j['prefix'] as String? ?? '',
    suffix: j['suffix'] as String? ?? '',
    separator: j['separator'] as String? ?? '/',
    padding: (j['padding'] as num?)?.toInt() ?? 5,
    resetYearly: j['resetYearly'] as bool? ?? true,
    isCustom: j['isCustom'] as bool? ?? false,
    nextPreview: j['nextPreview'] as String? ?? '',
    nextSeq: (j['nextSeq'] as num?)?.toInt() ?? 1,
    financialYear: j['financialYear'] as String? ?? '',
  );
}

/// Pure formatter — ported from the backend's `formatDocNo`
/// (`backend/src/shared/numbering/sequences.ts`). A ~10-line pure function,
/// safe to duplicate rather than share across the Dart/Node boundary. Lets
/// the editor sheet recompute the preview locally as the merchant edits
/// prefix/suffix/padding, without a round-trip per keystroke.
String formatDocNoPreview({
  required String prefix,
  required String suffix,
  required String separator,
  required int padding,
  required bool resetYearly,
  required int seq,
  required String financialYear,
}) {
  final parts = [
    prefix,
    if (resetYearly) financialYear,
    seq.toString().padLeft(padding, '0'),
  ].where((p) => p.isNotEmpty).toList();
  var out = parts.join(separator);
  if (suffix.isNotEmpty) out += '$separator$suffix';
  return out;
}
