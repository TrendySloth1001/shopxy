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
  id: z.number(),
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
    .object({ id: z.number(), invoiceNo: z.string().nullish() })
    .passthrough(),
});
export type StockDraft = z.infer<typeof stockDraftSchema>;

export type CreateStockInput = {
  productId: number;
  type: StockType;
  quantity: number;
  unitPrice?: number;
  vendorId?: number;
  partyId?: number;
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
  id: z.number(),
  productId: z.number(),
  type: z.string(),
  direction: z.string().nullish(),
  quantity: decimalToNumber,
  unitPrice: nullableDecimal,
  vendorId: z.number().nullish(),
  vendor: z.object({ id: z.number(), name: z.string() }).nullish(),
  supplierName: z.string().nullish(),
  purchasePriceMode: z.string().nullish(),
  createdAt: z.string(),
});
export type StockTxn = z.infer<typeof stockTxnSchema>;

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
