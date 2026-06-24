import { z } from "zod";

/**
 * Merchant-side return shapes, mirroring the backend returns module served at
 * `/orders/returns`. Returns are initiated by customers; the merchant works the
 * inbox: approve / reject → mark picked-up → mark received → refund (refunds the
 * buyer's original payment method and restocks). Money is rupees (Decimal
 * serialised as number).
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

/**
 * Result of POST /orders/returns/:id/refund. The refund goes to the buyer's
 * original payment instrument via the gateway. `refundStatus`:
 *   REFUNDED            — money sent back to the original payment method
 *   NO_PAYMENT          — nothing was paid online (COD); settle offline
 *   FAILED              — gateway rejected the refund
 *   NOTHING_TO_REFUND   — zero refundable amount
 */
export const REFUND_STATUSES = ["REFUNDED", "NO_PAYMENT", "FAILED", "NOTHING_TO_REFUND"] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export const refundResultSchema = z.object({
  ok: z.boolean().default(true),
  refundAmount: z.coerce.number().default(0),
  refundStatus: z.string().default("NO_PAYMENT"),
});
export type RefundResult = z.infer<typeof refundResultSchema>;

export function refundStatusMessage(r: RefundResult): string {
  switch (r.refundStatus) {
    case "REFUNDED":
      return `Refund of ${r.refundAmount} issued to the customer's original payment method.`;
    case "NO_PAYMENT":
      return "No online payment to refund — settle with the customer offline.";
    case "FAILED":
      return "The refund could not be processed by the payment gateway. Try again.";
    case "NOTHING_TO_REFUND":
      return "There was nothing to refund.";
    default:
      return "Refund processed.";
  }
}

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
