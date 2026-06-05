import { z } from "zod";

/**
 * Stock-adjustment shapes, mirroring the backend `stock-adjustments` module
 * (`/stock-adjustments`). A manual correction to on-hand stock — damage,
 * expiry, shrinkage, a recount or an opening balance — that posts an IN/OUT
 * movement to the stock ledger. Quantities are Decimals serialised as numbers.
 */

export const ADJUSTMENT_REASONS = ["DAMAGE", "EXPIRED", "SHRINKAGE", "RECOUNT", "OPENING"] as const;
export type AdjustmentReason = (typeof ADJUSTMENT_REASONS)[number];

export const ADJUSTMENT_REASON_LABELS: Record<string, string> = {
  DAMAGE: "Damage",
  EXPIRED: "Expired",
  SHRINKAGE: "Shrinkage",
  RECOUNT: "Recount",
  OPENING: "Opening stock",
};

export const ADJUSTMENT_REASON_CLASSES: Record<string, string> = {
  DAMAGE: "bg-error-soft text-error",
  EXPIRED: "bg-error-soft text-error",
  SHRINKAGE: "bg-error-soft text-error",
  RECOUNT: "bg-accent-amber-soft text-accent-amber",
  OPENING: "bg-accent-indigo-soft text-accent-indigo",
};

/** Default movement direction for a reason; RECOUNT/OPENING let the user pick. */
export function defaultDirection(reason: string): "IN" | "OUT" {
  return reason === "OPENING" ? "IN" : "OUT";
}
export function directionIsEditable(reason: string): boolean {
  return reason === "RECOUNT" || reason === "OPENING";
}

export const adjustmentItemSchema = z
  .object({
    id: z.number().optional(),
    productId: z.number(),
    productName: z.string().nullish(),
    productSku: z.string().nullish(),
    unit: z.string().nullish(),
    quantity: z.coerce.number().default(0),
    unitCost: z.coerce.number().nullish(),
    note: z.string().nullish(),
  })
  .passthrough();
export type AdjustmentItem = z.infer<typeof adjustmentItemSchema>;

export const adjustmentSchema = z
  .object({
    id: z.number(),
    adjustmentNo: z.string(),
    reasonCode: z.string(),
    direction: z.string(),
    note: z.string().nullish(),
    createdBy: z.object({ id: z.number(), name: z.string() }).nullish(),
    createdAt: z.string(),
    items: z
      .array(adjustmentItemSchema)
      .nullish()
      .transform((v) => v ?? []),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type Adjustment = z.infer<typeof adjustmentSchema>;

export const adjustmentListSchema = z.object({
  data: z
    .array(adjustmentSchema)
    .nullish()
    .transform((v) => v ?? []),
  total: z.coerce.number().default(0),
});

export function adjustmentItemCount(a: Adjustment): number {
  return a._count?.items ?? a.items.length;
}
