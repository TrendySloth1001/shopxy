import type { Invoice } from "./schema";

/** Status badge colours, matching the vendor/party doc-status chips. */
export const INVOICE_STATUS_CLASSES: Record<string, string> = {
  DRAFT: "bg-accent-amber-soft text-accent-amber",
  CONFIRMED: "bg-success-soft text-success",
  CANCELLED: "bg-error-soft text-error",
};

export const INVOICE_STATUS_LABELS: Record<string, string> = {
  DRAFT: "Draft",
  CONFIRMED: "Confirmed",
  CANCELLED: "Cancelled",
};

/** "IGST" for interstate, else "CGST + SGST". */
export function gstTypeLabel(inv: Invoice): string {
  return inv.isInterstate ? "IGST" : "CGST + SGST";
}

/** A line in the create/edit editor — the merchant edits qty/price/tax only. */
export type InvoiceLineDraft = {
  productId: string;
  productName: string;
  productSku: string;
  hsn: string | null;
  unit: string;
  quantity: number;
  unitPrice: number;
  taxPercent: number;
  /// Whether unitPrice already contains GST, seeded from the product's own
  /// pricingMode when it's added to the line (see resolveProductPricing on
  /// the backend). Per-line, not invoice-wide — an invoice can mix a
  /// TAX_INCLUSIVE product with a TAX_EXCLUSIVE one, same as the backend
  /// engine allows.
  isPriceInclusive: boolean;
  /// Discount on this line, in rupees, off `quantity × unitPrice`. Applied
  /// before the header discount is apportioned, matching the backend engine
  /// and the Flutter editor. Absent on older drafts — treat as 0.
  discount: number;
};

export type InvoiceTotals = {
  subtotal: number;
  discount: number;
  taxable: number;
  tax: number;
  igst: number;
  cgst: number;
  sgst: number;
  roundOff: number;
  total: number;
};

/**
 * Preview of the invoice totals as the merchant builds it. Mirrors the Flutter
 * editor and the backend engine: the header discount is clamped to the subtotal
 * and apportioned across lines before per-line tax, then the grand total is
 * rounded to the nearest rupee. The backend recomputes authoritatively on save
 * — this is a live preview only.
 *
 * Each line's own `isPriceInclusive` selects its tax convention, matching the
 * backend's per-line `isPriceInclusive` flag:
 *   - exclusive (the historical default): `unitPrice` is the pre-tax amount;
 *     tax is added on top → total = taxable + tax.
 *   - inclusive (a TAX_INCLUSIVE product, or the marketplace/customer-order
 *     path): `unitPrice` ALREADY contains tax; back it out of the discounted
 *     line amount so it is NOT double-added. taxable = amount × 100 / (100 + rate).
 * An invoice can mix both — the split is per line, same as the backend engine.
 */
export function computeInvoiceTotals(
  lines: InvoiceLineDraft[],
  headerDiscount: number,
  interstate: boolean,
): InvoiceTotals {
  // Each line's base is qty × price MINUS its own discount, floored at 0 —
  // the same base the backend apportions the header discount over. Getting
  // this wrong shows the merchant a total the saved invoice won't match.
  const lineBaseOf = (l: InvoiceLineDraft) =>
    Math.max(l.quantity * l.unitPrice - (l.discount || 0), 0);
  const subtotal = lines.reduce((sum, l) => sum + lineBaseOf(l), 0);
  const discount = Math.min(Math.max(headerDiscount, 0), subtotal);

  let tax = 0;
  let taxable = 0;
  for (const l of lines) {
    const lineBase = lineBaseOf(l);
    const share = subtotal > 0 ? lineBase / subtotal : 0;
    const lineAmount = lineBase - share * discount;
    if (l.isPriceInclusive) {
      // Inclusive: the discounted line amount already contains tax — back it
      // out so the displayed tax matches the backend and isn't double-added.
      const lineTaxable = (lineAmount * 100) / (100 + l.taxPercent);
      taxable += lineTaxable;
      tax += lineAmount - lineTaxable;
    } else {
      // Exclusive: tax is charged on top of the discounted line amount.
      taxable += lineAmount;
      tax += (lineAmount * l.taxPercent) / 100;
    }
  }

  // Inclusive total = sum of inclusive line amounts (taxable + tax already);
  // exclusive total = taxable + tax. Both reduce to taxable + tax here.
  const rawTotal = taxable + tax;
  const total = Math.round(rawTotal);
  const roundOff = total - rawTotal;

  // CGST/SGST split: round CGST to the paisa and let SGST absorb the remainder
  // so cgst + sgst === tax exactly (mirrors the backend, which splits the GST
  // total via `sgst = gstTotal − cgst` rather than two independent halves).
  const cgst = interstate ? 0 : Math.round((tax / 2) * 100) / 100;
  const sgst = interstate ? 0 : Math.round((tax - cgst) * 100) / 100;

  return {
    subtotal,
    discount,
    taxable,
    tax,
    igst: interstate ? tax : 0,
    cgst,
    sgst,
    roundOff,
    total,
  };
}
