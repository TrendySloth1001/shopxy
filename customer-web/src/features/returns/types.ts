import { z } from "zod";

export const RETURN_REASONS = [
  "DAMAGED",
  "WRONG_ITEM",
  "NOT_AS_DESCRIBED",
  "SIZE_FIT",
  "CHANGED_MIND",
  "DEFECTIVE",
  "OTHER",
] as const;
export type ReturnReason = (typeof RETURN_REASONS)[number];

export function reasonLabel(reason: string): string {
  switch (reason) {
    case "DAMAGED": return "Damaged";
    case "WRONG_ITEM": return "Wrong item";
    case "NOT_AS_DESCRIBED": return "Not as described";
    case "SIZE_FIT": return "Size/fit issue";
    case "CHANGED_MIND": return "Changed mind";
    case "DEFECTIVE": return "Defective";
    case "OTHER": return "Other";
    default: return reason;
  }
}

export const returnShopSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  shopName: z.string().nullable().optional(),
});

export const returnEventSchema = z.object({
  id: z.coerce.string(),
  type: z.string(),
  note: z.string().nullable().optional(),
  occurredAt: z.string(),
});
export type ReturnEvent = z.infer<typeof returnEventSchema>;

export const returnItemSchema = z.object({
  id: z.coerce.string(),
  quantity: z.coerce.number(),
  refundAmount: z.coerce.number(),
  reason: z.string(),
  purchaseRequestItem: z.object({
    id: z.coerce.string(),
    productId: z.coerce.string(),
    productName: z.string(),
    productSku: z.string().optional(),
    unit: z.string(),
    unitPrice: z.coerce.number(),
    quantity: z.coerce.number(),
    product: z
      .object({
        images: z.array(z.object({ url: z.string() })).optional(),
      })
      .optional(),
  }),
});
export type ReturnItem = z.infer<typeof returnItemSchema>;

export const returnRequestSchema = z.object({
  id: z.coerce.string(),
  status: z.string(),
  refundAmount: z.coerce.number(),
  refundMethod: z.string().nullable().optional(),
  note: z.string().nullable().optional(),
  decisionNote: z.string().nullable().optional(),
  walletEntryId: z.coerce.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  shopId: z.coerce.string(),
  customerUserId: z.coerce.string().optional(),
  requestId: z.coerce.string().optional(),
  shop: returnShopSchema,
  request: z
    .object({
      id: z.coerce.string(),
      customerOrderId: z.coerce.string(),
      status: z.string().optional(),
      customerName: z.string().optional(),
      customerAddress: z.string().nullable().optional(),
    })
    .optional(),
  items: z.array(returnItemSchema),
  events: z.array(returnEventSchema),
  canCancel: z.boolean().optional(),
});
export type ReturnRequest = z.infer<typeof returnRequestSchema>;

export const returnsPageSchema = z.object({
  data: z.array(returnRequestSchema),
  pagination: z.object({
    page: z.number(),
    limit: z.number(),
    total: z.coerce.number(),
    totalPages: z.number(),
  }),
});
export type ReturnsPage = z.infer<typeof returnsPageSchema>;

export function returnStatusVisual(status: string): {
  label: string;
  colorClass: string;
  bgClass: string;
} {
  switch (status) {
    case "REFUNDED":
      return { label: "Refunded", colorClass: "text-success", bgClass: "bg-success-soft" };
    case "REJECTED":
      return { label: "Rejected", colorClass: "text-error", bgClass: "bg-error-soft" };
    case "CANCELLED":
      return { label: "Cancelled", colorClass: "text-muted", bgClass: "bg-surface-tint" };
    case "PICKED_UP":
      return { label: "Picked up", colorClass: "text-brand-strong", bgClass: "bg-brand-soft" };
    case "RECEIVED":
      return { label: "Received", colorClass: "text-brand-strong", bgClass: "bg-brand-soft" };
    case "APPROVED":
      return { label: "Approved", colorClass: "text-brand-strong", bgClass: "bg-brand-soft" };
    default:
      return { label: "Requested", colorClass: "text-brand-strong", bgClass: "bg-brand-soft" };
  }
}

export function isReturnCancellable(status: string): boolean {
  return status === "REQUESTED";
}
