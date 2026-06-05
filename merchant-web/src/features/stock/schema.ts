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
