import type { Invoice } from "./schema";

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

export function gstTypeLabel(inv: Invoice): string {
  return inv.isInterstate ? "IGST" : "CGST + SGST";
}

export type InvoiceLineDraft = {
  productId: string;
  productName: string;
  productSku: string;
  hsn: string | null;
  unit: string;
  quantity: number;
  unitPrice: number;
  taxPercent: number;
  isPriceInclusive: boolean;
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

export function computeInvoiceTotals(
  lines: InvoiceLineDraft[],
  headerDiscount: number,
  interstate: boolean,
): InvoiceTotals {
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
      const lineTaxable = (lineAmount * 100) / (100 + l.taxPercent);
      taxable += lineTaxable;
      tax += lineAmount - lineTaxable;
    } else {
      taxable += lineAmount;
      tax += (lineAmount * l.taxPercent) / 100;
    }
  }

  const rawTotal = taxable + tax;
  const total = Math.round(rawTotal);
  const roundOff = total - rawTotal;

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
