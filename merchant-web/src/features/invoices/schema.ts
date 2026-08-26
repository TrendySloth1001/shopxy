import { z } from "zod";

export const INVOICE_TYPES = ["SALE", "PURCHASE"] as const;
export type InvoiceType = (typeof INVOICE_TYPES)[number];

export const INVOICE_STATUSES = ["DRAFT", "CONFIRMED", "CANCELLED"] as const;
export type InvoiceStatus = (typeof INVOICE_STATUSES)[number];

export const SALE_DOC_TYPES = ["TAX_INVOICE", "BILL_OF_SUPPLY", "ESTIMATE", "PROFORMA"] as const;

export const DOCUMENT_TYPE_LABELS: Record<string, string> = {
  TAX_INVOICE: "Tax invoice",
  BILL_OF_SUPPLY: "Bill of supply",
  ESTIMATE: "Estimate",
  PROFORMA: "Proforma",
  CREDIT_NOTE: "Credit note",
  DEBIT_NOTE: "Debit note",
};

export const invoiceItemSchema = z
  .object({
    id: z.coerce.string().optional(),
    productId: z.coerce.string(),
    productName: z.string().nullish(),
    productSku: z.string().nullish(),
    hsn: z.string().nullish(),
    unit: z.string().nullish(),
    quantity: z.coerce.number().default(0),
    unitPrice: z.coerce.number().default(0),
    taxPercent: z.coerce.number().default(0),
    isPriceInclusive: z.boolean().default(false),
    discount: z.coerce.number().default(0),
    taxableValue: z.coerce.number().default(0),
    igstAmount: z.coerce.number().default(0),
    cgstAmount: z.coerce.number().default(0),
    sgstAmount: z.coerce.number().default(0),
    cessRate: z.coerce.number().default(0),
    cessAmount: z.coerce.number().default(0),
    total: z.coerce.number().default(0),
  })
  .passthrough();
export type InvoiceItem = z.infer<typeof invoiceItemSchema>;

export const invoiceSchema = z
  .object({
    id: z.coerce.string(),
    invoiceNo: z.string(),
    type: z.string(),
    status: z.string(),
    documentType: z.string().default("TAX_INVOICE"),
    financialYear: z.string().nullish(),
    partyId: z.coerce.string().nullish(),
    vendorId: z.coerce.string().nullish(),

    customerName: z.string().nullish(),
    customerPhone: z.string().nullish(),
    customerGstin: z.string().nullish(),
    customerAddress: z.string().nullish(),
    customerCity: z.string().nullish(),
    customerState: z.string().nullish(),
    customerStateCode: z.string().nullish(),
    customerPinCode: z.string().nullish(),
    customerPanNumber: z.string().nullish(),

    vendorName: z.string().nullish(),
    vendorPhone: z.string().nullish(),
    vendorGstin: z.string().nullish(),
    vendorAddress: z.string().nullish(),
    vendorCity: z.string().nullish(),
    vendorState: z.string().nullish(),
    vendorStateCode: z.string().nullish(),
    vendorPinCode: z.string().nullish(),
    vendorPanNumber: z.string().nullish(),

    placeOfSupplyStateCode: z.string().nullish(),
    isInterstate: z.boolean().default(false),

    subtotal: z.coerce.number().default(0),
    taxableValue: z.coerce.number().default(0),
    taxAmount: z.coerce.number().default(0),
    igstAmount: z.coerce.number().default(0),
    cgstAmount: z.coerce.number().default(0),
    sgstAmount: z.coerce.number().default(0),
    cessAmount: z.coerce.number().default(0),
    discount: z.coerce.number().default(0),
    roundOff: z.coerce.number().default(0),
    total: z.coerce.number().default(0),
    amountInWords: z.string().nullish(),
    note: z.string().nullish(),
    invoiceDate: z.string(),
    archivedAt: z.string().nullish(),
    convertedToInvoiceId: z.coerce.string().nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    items: z
      .array(invoiceItemSchema)
      .nullish()
      .transform((v) => v ?? []),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type Invoice = z.infer<typeof invoiceSchema>;

export const invoiceListSchema = z.object({
  data: z
    .array(invoiceSchema)
    .nullish()
    .transform((v) => v ?? []),
  pagination: z
    .object({
      total: z.coerce.number().default(0),
      page: z.coerce.number().optional(),
      limit: z.coerce.number().optional(),
    })
    .nullish(),
});

export function invoiceItemCount(inv: Invoice): number {
  return inv._count?.items ?? inv.items.length;
}

export function isSale(inv: Invoice): boolean {
  return inv.type === "SALE";
}

export function counterpartyName(inv: Invoice): string {
  if (isSale(inv)) return inv.customerName ?? "Walk-in customer";
  return inv.vendorName ?? "Vendor";
}
