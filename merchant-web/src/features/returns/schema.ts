import { z } from "zod";

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

export const RETURN_STATUS_CLASSES: Record<string, string> = {
  REQUESTED: "bg-accent-amber-soft text-accent-amber",
  APPROVED: "bg-accent-indigo-soft text-accent-indigo",
  PICKED_UP: "bg-accent-indigo-soft text-accent-indigo",
  RECEIVED: "bg-accent-indigo-soft text-accent-indigo",
  REFUNDED: "bg-success-soft text-success",
  REJECTED: "bg-error-soft text-error",
  CANCELLED: "bg-surface-tint text-muted",
};

const returnItemSchema = z
  .object({
    id: z.coerce.string(),
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
    id: z.coerce.string(),
    type: z.string(),
    note: z.string().nullish(),
    occurredAt: z.string(),
  })
  .passthrough();
export type ReturnEvent = z.infer<typeof returnEventSchema>;

export const returnSchema = z
  .object({
    id: z.coerce.string(),
    status: z.string(),
    refundAmount: z.coerce.number().default(0),
    refundMethod: z.string().nullish(),
    note: z.string().nullish(),
    decisionNote: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().optional(),
    requestId: z.coerce.string().nullish(),
    request: z
      .object({
        id: z.coerce.string().nullish(),
        customerOrderId: z.coerce.string().nullish(),
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

export const REFUND_STATUSES = ["REFUNDED", "NO_PAYMENT", "FAILED", "NOTHING_TO_REFUND"] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export const refundResultSchema = z.object({
  ok: z.boolean().default(true),
  refundAmount: z.coerce.number().default(0),
  refundStatus: z.string().default("NO_PAYMENT"),
});
export type RefundResult = z.infer<typeof refundResultSchema>;

export function refundStatusMessageKey(r: RefundResult): string {
  switch (r.refundStatus) {
    case "REFUNDED":
      return "refundMessage.refunded";
    case "NO_PAYMENT":
      return "refundMessage.noPayment";
    case "FAILED":
      return "refundMessage.failed";
    case "NOTHING_TO_REFUND":
      return "refundMessage.nothing";
    default:
      return "refundMessage.processed";
  }
}

export function customerName(r: MerchantReturn, fallback: string): string {
  return r.request?.customerName ?? fallback;
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
