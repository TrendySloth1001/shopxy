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

  final bool isCustom;

  final String nextPreview;

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
