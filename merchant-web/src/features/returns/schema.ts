import { z } from "zod";

/**
 * Merchant-side return shapes, mirroring the backend returns module served at
 * `/orders/returns`. Returns are initiated by customers; the merchant works the
 * inbox: approve / reject → mark picked-up → mark received → refund (credits the
 * buyer's wallet and restocks). Money is rupees (Decimal serialised as number).
 */

export const RETURN_STATUSES = [
  "REQUESTED",
  "APPROVED",
  "PICKED_UP",
  "RECEIVED",
  "REFUNDED",
  "REJECTED",
  "CANCELLED",
] as const;
export type ReturnStatus = (typeof RETURN_STATUSES)[number];

export const RETURN_STATUS_LABELS: Record<string, string> = {
  REQUESTED: "Requested",
  APPROVED: "Approved",
  PICKED_UP: "Picked up",
  RECEIVED: "Received",
  REFUNDED: "Refunded",
  REJECTED: "Rejected",
  CANCELLED: "Cancelled",
};

export const RETURN_STATUS_CLASSES: Record<string, string> = {
  REQUESTED: "bg-accent-amber-soft text-accent-amber",
  APPROVED: "bg-accent-indigo-soft text-accent-indigo",
  PICKED_UP: "bg-accent-indigo-soft text-accent-indigo",
  RECEIVED: "bg-accent-indigo-soft text-accent-indigo",
  REFUNDED: "bg-success-soft text-success",
  REJECTED: "bg-error-soft text-error",
  CANCELLED: "bg-surface-tint text-muted",
};

export const RETURN_REASON_LABELS: Record<string, string> = {
  DAMAGED: "Damaged on arrival",
  WRONG_ITEM: "Wrong item sent",
  NOT_AS_DESCRIBED: "Not as described",
  SIZE_FIT: "Size / fit issue",
  CHANGED_MIND: "Changed mind",
  DEFECTIVE: "Defective / not working",
  OTHER: "Other",
};

const returnItemSchema = z
  .object({
    id: z.number(),
    quantity: z.coerce.number().default(0),
    refundAmount: z.coerce.number().default(0),
    reason: z.string().nullish(),
    purchaseRequestItem: z
      .object({
        productName: z.string().nullish(),
        productSku: z.string().nullish(),
        unit: z.string().nullish(),
        unitPrice: z.coerce.number().default(0),
      })
      .passthrough()
      .nullish(),
  })
  .passthrough();
export type ReturnItem = z.infer<typeof returnItemSchema>;

const returnEventSchema = z
  .object({
    id: z.number(),
    type: z.string(),
    note: z.string().nullish(),
    occurredAt: z.string(),
  })
  .passthrough();
export type ReturnEvent = z.infer<typeof returnEventSchema>;

export const returnSchema = z
  .object({
    id: z.number(),
    status: z.string(),
    refundAmount: z.coerce.number().default(0),
    refundMethod: z.string().nullish(),
    note: z.string().nullish(),
    decisionNote: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().optional(),
    requestId: z.number().nullish(),
    request: z
      .object({
        id: z.number().nullish(),
        customerOrderId: z.number().nullish(),
        customerName: z.string().nullish(),
        customerAddress: z.string().nullish(),
      })
      .passthrough()
      .nullish(),
    items: z
      .array(returnItemSchema)
      .nullish()
      .transform((v) => v ?? []),
    events: z
      .array(returnEventSchema)
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();
export type MerchantReturn = z.infer<typeof returnSchema>;

export const returnListSchema = z.object({
  data: z
    .array(returnSchema)
    .nullish()
    .transform((v) => v ?? []),
  total: z.coerce.number().default(0),
});

export function customerName(r: MerchantReturn): string {
  return r.request?.customerName ?? `Customer #${r.id}`;
}
export function canApprove(r: MerchantReturn): boolean {
  return r.status === "REQUESTED";
}
export function canMarkPickedUp(r: MerchantReturn): boolean {
  return r.status === "APPROVED";
}
export function canMarkReceived(r: MerchantReturn): boolean {
  return r.status === "APPROVED" || r.status === "PICKED_UP";
}
export function canRefund(r: MerchantReturn): boolean {
  return r.status === "APPROVED" || r.status === "PICKED_UP" || r.status === "RECEIVED";
}
