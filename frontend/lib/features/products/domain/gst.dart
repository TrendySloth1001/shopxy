class GstBreakdown {
  const GstBreakdown({
    required this.rate,
    required this.taxable,
    required this.gst,
    required this.cgst,
    required this.sgst,
    required this.totalPayable,
  });

  final double rate;

  final double taxable;

  final double gst;

  final double cgst;

  final double sgst;

  final double totalPayable;
}

GstBreakdown gstFromInclusive(double gross, double ratePercent) {
  final rate = ratePercent < 0 ? 0.0 : ratePercent;
  final taxable = rate > 0 ? (gross * 100) / (100 + rate) : gross;
  final gst = gross - taxable;
  final cgst = (gst / 2 * 100).roundToDouble() / 100;
  final sgst = (gst - cgst);
  return GstBreakdown(
    rate: rate,
    taxable: taxable,
    gst: gst,
    cgst: cgst,
    sgst: sgst,
    totalPayable: gross,
  );
}

GstBreakdown gstFromExclusive(double price, double ratePercent) {
  final rate = ratePercent < 0 ? 0.0 : ratePercent;
  final gst = price * rate / 100;
  final cgst = (gst / 2 * 100).roundToDouble() / 100;
  final sgst = (gst - cgst);
  return GstBreakdown(
    rate: rate,
    taxable: price,
    gst: gst,
    cgst: cgst,
    sgst: sgst,
    totalPayable: price + gst,
  );
}

GstBreakdown? gstBreakdownForProduct(
  double price,
  double taxPercent,
  String pricingMode,
) {
  if (pricingMode == 'NO_GST' || taxPercent <= 0) return null;
  return pricingMode == 'TAX_INCLUSIVE'
      ? gstFromInclusive(price, taxPercent)
      : gstFromExclusive(price, taxPercent);
}
