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
  productId: number;
  productName: string;
  productSku: string;
  hsn: string | null;
  unit: string;
  quantity: number;
  unitPrice: number;
  taxPercent: number;
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
 * editor: the header discount is clamped to the subtotal and apportioned across
 * lines before per-line tax, then the grand total is rounded to the nearest
 * rupee. The backend recomputes authoritatively on save — this is a live
 * preview only.
 */
export function computeInvoiceTotals(
  lines: InvoiceLineDraft[],
  headerDiscount: number,
  interstate: boolean,
): InvoiceTotals {
  const subtotal = lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0);
  const discount = Math.min(Math.max(headerDiscount, 0), subtotal);
  const taxable = subtotal - discount;

  let tax = 0;
  for (const l of lines) {
    const lineBase = l.quantity * l.unitPrice;
    const share = subtotal > 0 ? lineBase / subtotal : 0;
    const lineTaxable = lineBase - share * discount;
    tax += (lineTaxable * l.taxPercent) / 100;
  }

  const rawTotal = taxable + tax;
  const total = Math.round(rawTotal);
  const roundOff = total - rawTotal;

  return {
    subtotal,
    discount,
    taxable,
    tax,
    igst: interstate ? tax : 0,
    cgst: interstate ? 0 : tax / 2,
    sgst: interstate ? 0 : tax / 2,
    roundOff,
    total,
  };
}
