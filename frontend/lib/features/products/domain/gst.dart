/// GST maths for the catalogue. A product's `pricingMode` decides whether its
/// stored mrp/sellingPrice already contains GST ('TAX_INCLUSIVE' — back the
/// tax OUT of the price) or GST is added on top when billed
/// ('TAX_EXCLUSIVE' — the default), or the product never carries GST at all
/// ('NO_GST'). This mirrors the backend's `resolveProductPricing()` and the
/// merchant-web `gst.ts` helper — same three modes, same meaning — so the
/// merchant sees the exact convention their invoices/quotations will bill
/// under, not a blanket "prices are inclusive" assumption.
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
    required this.totalPayable,
  });

  /// The applied GST rate, e.g. 18.
  final double rate;

  /// Pre-tax (taxable) value.
  final double taxable;

  /// Total GST on top of/backed out of the price.
  final double gst;

  /// Half of [gst] — Central GST for an intra-state sale.
  final double cgst;

  /// Half of [gst] — State GST for an intra-state sale.
  final double sgst;

  /// The amount actually payable — equals the price when inclusive, price +
  /// gst when exclusive.
  final double totalPayable;
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
    totalPayable: gross,
  );
}

/// Add GST on top of a tax-exclusive price. [price] is the taxable value itself.
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

/// Mode-aware entry point — the one callers in the products feature should
/// use instead of reaching for [gstFromInclusive] directly. Returns `null`
/// for 'NO_GST' (nothing to break down) and for a zero rate under any mode
/// (same reasoning) — callers fall back to their own zero-tax display.
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
