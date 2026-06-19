import { z } from "zod";

export const saleLineSchema = z.object({
  productId: z.number(),
  name: z.string(),
  sku: z.string(),
  imageUrl: z.string().nullable(),
  quantity: z.number(),
  unitPrice: z.number(),
  lineDiscount: z.number(),
  taxPercent: z.number(),
  taxableValue: z.number(),
  total: z.number(),
});
export type SaleLine = z.infer<typeof saleLineSchema>;

export const saleTotalsSchema = z.object({
  itemCount: z.number(),
  subtotal: z.number(),
  discount: z.number(),
  taxableValue: z.number(),
  taxAmount: z.number(),
  cgst: z.number(),
  sgst: z.number(),
  igst: z.number(),
  cess: z.number(),
  roundOff: z.number(),
  total: z.number(),
});

export const saleSnapshotSchema = z.object({
  sale: z.object({
    id: z.number(),
    status: z.string(),
    version: z.number(),
    partyId: z.number().nullable(),
    customerName: z.string().nullable(),
    customerPhone: z.string().nullable(),
    headerDiscount: z.number(),
    note: z.string().nullable(),
    invoiceId: z.number().nullable(),
  }),
  lines: z.array(saleLineSchema),
  totals: saleTotalsSchema,
});
export type SaleSnapshot = z.infer<typeof saleSnapshotSchema>;

/** Unknown-scan response (P2 quick-add hook point). */
export const unknownScanSchema = z.object({ unknown: z.literal(true), code: z.string() });

export const ticketSchema = z.object({
  ticket: z.string(),
  path: z.string(),
  expiresInMs: z.number(),
});
export type Ticket = z.infer<typeof ticketSchema>;

export const checkoutResultSchema = z.object({
  invoiceId: z.number(),
  invoiceNo: z.string(),
  total: z.union([z.string(), z.number()]),
  paymentRef: z.string().nullable(),
  mode: z.string().nullable(),
  replayed: z.boolean(),
});
export type CheckoutResult = z.infer<typeof checkoutResultSchema>;

export const TENDER_MODES = ["CASH", "UPI", "CARD", "OTHER"] as const;
export type TenderMode = (typeof TENDER_MODES)[number];

/** Pay-session returned by the `payOnline` command — opens Razorpay Checkout. */
export const posPaySessionSchema = z.object({
  intentId: z.number(),
  provider: z.string(),
  providerOrderRef: z.string(),
  amount: z.number(),
  currency: z.string(),
  clientParams: z.object({
    key: z.string(),
    order_id: z.string(),
    amount: z.number(),
    currency: z.string().optional(),
  }),
  reused: z.boolean(),
});
export type PosPaySession = z.infer<typeof posPaySessionSchema>;

export type ConnStatus = "connecting" | "live" | "reconnecting" | "offline";

/** A catalogue search hit for the "add without a barcode" picker. */
export const productSearchResultSchema = z.object({
  id: z.number(),
  name: z.string(),
  sku: z.string(),
  sellingPrice: z.number(),
  mrp: z.number(),
  stock: z.number(),
  imageUrl: z.string().nullable(),
});
export type ProductSearchResult = z.infer<typeof productSearchResultSchema>;

/** A parked (held) bill summary from the `listOpen` command. */
export const openSaleSummarySchema = z.object({
  id: z.number(),
  customerName: z.string().nullable(),
  lineCount: z.number(),
  updatedAt: z.string(),
});
export type OpenSaleSummary = z.infer<typeof openSaleSummarySchema>;
