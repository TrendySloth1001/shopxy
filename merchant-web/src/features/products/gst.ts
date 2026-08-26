export type ProductPricingMode = "TAX_EXCLUSIVE" | "TAX_INCLUSIVE" | "NO_GST";

export type GstBreakdown = {
  rate: number;
  taxable: number;
  gst: number;
  cgst: number;
  sgst: number;
  totalPayable: number;
};

export function gstFromInclusive(gross: number, ratePercent: number): GstBreakdown {
  const rate = Math.max(0, ratePercent);
  const taxable = rate > 0 ? (gross * 100) / (100 + rate) : gross;
  const gst = gross - taxable;
  return { rate, taxable, gst, cgst: gst / 2, sgst: gst / 2, totalPayable: gross };
}

export function gstFromExclusive(price: number, ratePercent: number): GstBreakdown {
  const rate = Math.max(0, ratePercent);
  const gst = (price * rate) / 100;
  return { rate, taxable: price, gst, cgst: gst / 2, sgst: gst / 2, totalPayable: price + gst };
}

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
