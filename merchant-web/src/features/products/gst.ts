/**
 * GST maths for the catalogue. Catalogue selling/MRP prices are stored
 * GST-inclusive (see ACCOUNTING_AUDIT — prices are tax-inclusive), so to show
 * the merchant "how much of this price is tax" we BACK the GST out of the gross
 * price rather than adding it on top. This mirrors the inclusive branch of
 * `computeInvoiceTotals` in the invoices feature.
 *
 * An intra-state sale (the default for a single-shop merchant) splits GST evenly
 * into CGST + SGST; an inter-state sale charges the whole amount as IGST. We show
 * the CGST/SGST split because that's the common case for a shop billing within
 * its own state; the total is identical either way.
 */
export type GstBreakdown = {
  /** The applied GST rate, e.g. 18. */
  rate: number;
  /** Pre-tax (taxable) value backed out of the inclusive price. */
  taxable: number;
  /** Total GST contained in the inclusive price. */
  gst: number;
  /** Half of `gst` — Central GST for an intra-state sale. */
  cgst: number;
  /** Half of `gst` — State GST for an intra-state sale. */
  sgst: number;
};

/**
 * Split a tax-inclusive price into its taxable value and GST components.
 * `gross` is the price the customer pays (already includes GST).
 */
export function gstFromInclusive(gross: number, ratePercent: number): GstBreakdown {
  const rate = Math.max(0, ratePercent);
  const taxable = rate > 0 ? (gross * 100) / (100 + rate) : gross;
  const gst = gross - taxable;
  return { rate, taxable, gst, cgst: gst / 2, sgst: gst / 2 };
}
