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

export const TENDER_MODES = ["CASH", "UPI", "CARD", "OTHER"] as const;
export type TenderMode = (typeof TENDER_MODES)[number];

export type ConnStatus = "connecting" | "live" | "reconnecting" | "offline";
