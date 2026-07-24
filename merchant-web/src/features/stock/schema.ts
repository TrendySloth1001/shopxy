import { z } from "zod";

/**
 * Stock movements — the web mirror of the Flutter `StockBottomSheet`.
 * STOCK_IN = a purchase (counterparty: a vendor); STOCK_OUT = a sale
 * (counterparty: a party/customer). The backend (`POST /stock`) turns the
 * movement into a DRAFT invoice; stock only posts once that draft is confirmed.
 */
export const STOCK_TYPES = ["STOCK_IN", "STOCK_OUT"] as const;
export type StockType = (typeof STOCK_TYPES)[number];

/** A selectable vendor from `GET /stock/suppliers`. */
export const supplierVendorSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  phone: z.string().nullish(),
});
export type SupplierVendor = z.infer<typeof supplierVendorSchema>;

export const suppliersResponseSchema = z.object({
  vendors: z
    .array(supplierVendorSchema)
    .nullish()
    .transform((v) => v ?? []),
  freeTextSuppliers: z
    .array(z.string())
    .nullish()
    .transform((v) => v ?? []),
});
export type SuppliersResponse = z.infer<typeof suppliersResponseSchema>;

/** `POST /stock` returns the draft invoice it created — we only need its id. */
export const stockDraftSchema = z.object({
  draftInvoice: z
    .object({ id: z.coerce.string(), invoiceNo: z.string().nullish() })
    .passthrough(),
});
export type StockDraft = z.infer<typeof stockDraftSchema>;

export type CreateStockInput = {
  productId: string;
  type: StockType;
  quantity: number;
  unitPrice?: number;
  vendorId?: string;
  partyId?: string;
  note?: string;
};

/**
 * One stock-ledger row from `GET /stock`. Prisma serialises Decimal columns as
 * strings, so the numeric fields are coerced. Only the fields the supplier
 * price-history view needs are modelled; the rest pass through unread.
 */
const decimalToNumber = z
  .union([z.string(), z.number()])
  .transform((v) => Number(v));
const nullableDecimal = z
  .union([z.string(), z.number(), z.null()])
  .nullish()
  .transform((v) => (v === null || v === undefined ? null : Number(v)));

export const stockTxnSchema = z.object({
  id: z.coerce.string(),
  productId: z.coerce.string(),
  type: z.string(),
  direction: z.string().nullish(),
  reasonCode: z.string().nullish(),
  sourceType: z.string().nullish(),
  sourceId: z.coerce.string().nullish(),
  quantity: decimalToNumber,
  unitPrice: nullableDecimal,
  stockAfter: nullableDecimal,
  vendorId: z.coerce.string().nullish(),
  vendor: z.object({ id: z.coerce.string(), name: z.string() }).nullish(),
  supplierName: z.string().nullish(),
  purchasePriceMode: z.string().nullish(),
  reversesId: z.coerce.string().nullish(),
  note: z.string().nullish(),
  productUnit: z.string().nullish(),
  createdBy: z.object({ id: z.coerce.string(), name: z.string().nullish() }).nullish(),
  createdAt: z.string(),
});
export type StockTxn = z.infer<typeof stockTxnSchema>;

/** 'IN' side of the ledger (falls back to the legacy `type` column). */
export function isStockIn(t: StockTxn): boolean {
  return t.direction ? t.direction === "IN" : t.type === "STOCK_IN";
}

/** This row reverses (cancels) an earlier one. */
export function isReversal(t: StockTxn): boolean {
  return t.reversesId != null;
}

/** Whether the row has an openable source document (invoice / challan). */
export function hasSourceDocument(t: StockTxn): boolean {
  return (
    t.sourceId != null &&
    t.sourceType !== "MANUAL" &&
    t.sourceType !== "OPENING"
  );
}

/** Human label for a ledger reason code. */
export function reasonCodeLabel(code: string | null | undefined): string {
  switch (code) {
    case "SALE":
      return "Sale";
    case "PURCHASE":
      return "Purchase";
    case "OPENING":
      return "Opening balance";
    case "DAMAGE":
      return "Damaged";
    case "EXPIRED":
      return "Expired";
    case "SHRINKAGE":
      return "Shrinkage";
    case "RECOUNT":
      return "Recount correction";
    case "RETURN_IN":
      return "Customer return";
    case "RETURN_OUT":
      return "Return to vendor";
    case "TRANSFER_IN":
      return "Transfer in";
    case "TRANSFER_OUT":
      return "Transfer out";
    default:
      return code ?? "Movement";
  }
}

/** Human label for the source-document type. */
export function sourceTypeLabel(code: string | null | undefined): string {
  switch (code) {
    case "INVOICE":
      return "Invoice";
    case "CHALLAN":
      return "Challan";
    case "ADJUSTMENT":
      return "Adjustment";
    case "OPENING":
      return "Opening";
    case "MANUAL":
    default:
      return "Manual";
  }
}

/** `GET /stock` is paginated: `{ data, pagination }`. */
export const stockTxnListSchema = z.object({
  data: z
    .array(stockTxnSchema)
    .nullish()
    .transform((v) => v ?? []),
});
export type StockTxnList = z.infer<typeof stockTxnListSchema>;

/** Structured vendor name wins over a free-typed supplier name. */
export function displaySupplier(t: StockTxn): string | null {
  return t.vendor?.name ?? t.supplierName ?? null;
}

/** Human label for the per-supplier purchase-price policy. */
export function purchasePolicyLabel(mode: string | null | undefined): string {
  switch (mode) {
    case "WEIGHTED_AVERAGE":
      return "Weighted average";
    case "USE_LATEST":
      return "Use latest price";
    case "KEEP_CURRENT":
      return "Keep current price";
    default:
      return "—";
  }
}
