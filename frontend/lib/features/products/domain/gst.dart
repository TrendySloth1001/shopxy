/// GST maths for the catalogue. Catalogue selling/MRP prices are stored
/// GST-inclusive, so to show the merchant "how much of this price is tax" we
/// BACK the GST out of the gross price rather than adding it on top. This
/// mirrors the merchant-web `gst.ts` helper and the inclusive branch of the
/// invoice totals engine.
///
/// An intra-state sale (the default for a single-shop merchant) splits GST
/// evenly into CGST + SGST; an inter-state sale charges the same total as a
/// single IGST line. We surface the CGST/SGST split because that's the common
/// case for a shop billing within its own state.
class GstBreakdown {
  const GstBreakdown({
    required this.rate,
    required this.taxable,
    required this.gst,
    required this.cgst,
    required this.sgst,
  });

  /// The applied GST rate, e.g. 18.
  final double rate;

  /// Pre-tax (taxable) value backed out of the inclusive price.
  final double taxable;

  /// Total GST contained in the inclusive price.
  final double gst;

  /// Half of [gst] — Central GST for an intra-state sale.
  final double cgst;

  /// Half of [gst] — State GST for an intra-state sale.
  final double sgst;
}

/// Split a tax-inclusive price into its taxable value and GST components.
/// [gross] is the price the customer pays (already includes GST).
GstBreakdown gstFromInclusive(double gross, double ratePercent) {
  final rate = ratePercent < 0 ? 0.0 : ratePercent;
  final taxable = rate > 0 ? (gross * 100) / (100 + rate) : gross;
  final gst = gross - taxable;
  // Round CGST to the paisa and let SGST absorb the remainder so cgst + sgst
  // == gst exactly (mirrors the backend split, which derives sgst from the GST
  // total rather than rounding two independent halves).
  final cgst = (gst / 2 * 100).roundToDouble() / 100;
  final sgst = (gst - cgst);
  return GstBreakdown(
    rate: rate,
    taxable: taxable,
    gst: gst,
    cgst: cgst,
    sgst: sgst,
  );
}
