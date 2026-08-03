/**
 * GST maths for the catalogue. A product's `pricingMode` decides whether its
 * stored mrp/sellingPrice already contains GST (TAX_INCLUSIVE — back the tax
 * OUT of the price) or GST is added on top when billed (TAX_EXCLUSIVE — the
 * default), or the product never carries GST at all (NO_GST). This mirrors
 * the backend's `resolveProductPricing()` — same three modes, same meaning —
 * so the merchant sees the exact convention their invoices/quotations/orders
 * will actually bill under, not a blanket "prices are inclusive" assumption.
 *
 * An intra-state sale (the default for a single-shop merchant) splits GST evenly
 * into CGST + SGST; an inter-state sale charges the whole amount as IGST. We show
 * the CGST/SGST split because that's the common case for a shop billing within
 * its own state; the total is identical either way.
 */
export type ProductPricingMode = "TAX_EXCLUSIVE" | "TAX_INCLUSIVE" | "NO_GST";

export type GstBreakdown = {
  /** The applied GST rate, e.g. 18. */
  rate: number;
  /** Pre-tax (taxable) value. */
  taxable: number;
  /** Total GST on top of/backed out of the price. */
  gst: number;
  /** Half of `gst` — Central GST for an intra-state sale. */
  cgst: number;
  /** Half of `gst` — State GST for an intra-state sale. */
  sgst: number;
  /** The amount actually payable — equals `price` when inclusive, `price + gst` when exclusive. */
  totalPayable: number;
};

/**
 * Split a tax-inclusive price into its taxable value and GST components.
 * `gross` is the price the customer pays (already includes GST).
 */
export function gstFromInclusive(gross: number, ratePercent: number): GstBreakdown {
  const rate = Math.max(0, ratePercent);
  const taxable = rate > 0 ? (gross * 100) / (100 + rate) : gross;
  const gst = gross - taxable;
  return { rate, taxable, gst, cgst: gst / 2, sgst: gst / 2, totalPayable: gross };
}

/** Add GST on top of a tax-exclusive price. `price` is the taxable value itself. */
export function gstFromExclusive(price: number, ratePercent: number): GstBreakdown {
  const rate = Math.max(0, ratePercent);
  const gst = (price * rate) / 100;
  return { rate, taxable: price, gst, cgst: gst / 2, sgst: gst / 2, totalPayable: price + gst };
}

/**
 * Mode-aware entry point — the one callers in the products feature should
 * use instead of reaching for `gstFromInclusive` directly. Returns `null`
 * for NO_GST (nothing to break down; callers fall back to their own
 * zero-tax display) and for a zero rate under any mode (same reasoning).
 */
export function gstBreakdownForProduct(
  price: number,
  taxPercent: number,
  mode: ProductPricingMode,
): GstBreakdown | null {
  if (mode === "NO_GST" || !taxPercent || taxPercent <= 0) return null;
  return mode === "TAX_INCLUSIVE"
    ? gstFromInclusive(price, taxPercent)
    : gstFromExclusive(price, taxPercent);
}
