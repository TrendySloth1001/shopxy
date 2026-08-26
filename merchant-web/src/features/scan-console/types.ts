import { z } from "zod";

export const ticketSchema = z.object({
  ticket: z.string(),
  path: z.string(),
  expiresInMs: z.number(),
});
export type Ticket = z.infer<typeof ticketSchema>;

export const scanItemSchema = z.object({
  scanId: z.string(),
  productId: z.coerce.string(),
  name: z.string(),
  sku: z.string(),
  barcode: z.string().nullable(),
  sellingPrice: z.string(),
  mrp: z.string().nullable(),
  imageUrl: z.string().nullable(),
  scannedAt: z.string(),
  scannedBy: z.number(),
});
export type ScanItem = z.infer<typeof scanItemSchema>;

export const presenceSchema = z.object({
  consoles: z.number(),
  scanners: z.number(),
});
export type Presence = z.infer<typeof presenceSchema>;

export const scanEventSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("connected"),
    shopId: z.coerce.string(),
    role: z.enum(["scanner", "console"]),
    presence: presenceSchema,
  }),
  z.object({ type: z.literal("presence"), presence: presenceSchema }),
  z.object({ type: z.literal("scan"), scan: scanItemSchema }),
  z.object({
    type: z.literal("ack"),
    matched: z.boolean(),
    code: z.string(),
    name: z.string().optional(),
    sku: z.string().optional(),
  }),
  z.object({ type: z.literal("clear"), by: z.number() }),
]);
export type ScanEvent = z.infer<typeof scanEventSchema>;

export type ConsoleRow = {
  productId: string;
  name: string;
  sku: string;
  barcode: string | null;
  unitPrice: number;
  mrp: number | null;
  imageUrl: string | null;
  qty: number;
  lastScannedAt: string;
};

export type ConsoleStatus = "connecting" | "live" | "reconnecting" | "error";
