import { z } from "zod";

export const CHALLAN_STATUSES = ["PENDING", "CONVERTED", "CANCELLED"] as const;
export type ChallanStatus = (typeof CHALLAN_STATUSES)[number];

export const CHALLAN_STATUS_LABELS: Record<string, string> = {
  PENDING: "Pending",
  CONVERTED: "Converted",
  CANCELLED: "Cancelled",
};

export const CHALLAN_STATUS_CLASSES: Record<string, string> = {
  PENDING: "bg-accent-amber-soft text-accent-amber",
  CONVERTED: "bg-success-soft text-success",
  CANCELLED: "bg-error-soft text-error",
};

export const challanItemSchema = z
  .object({
    id: z.coerce.string().optional(),
    productId: z.coerce.string(),
    productName: z.string().nullish(),
    productSku: z.string().nullish(),
    unit: z.string().nullish(),
    quantity: z.coerce.number().default(0),
  })
  .passthrough();
export type ChallanItem = z.infer<typeof challanItemSchema>;

export const challanSchema = z
  .object({
    id: z.coerce.string(),
    challanNo: z.string(),
    status: z.string(),
    partyId: z.coerce.string().nullish(),
    partyName: z.string().nullish(),
    partyPhone: z.string().nullish(),
    note: z.string().nullish(),
    invoiceId: z.coerce.string().nullish(),
    invoice: z.object({ id: z.coerce.string(), invoiceNo: z.string(), status: z.string().nullish() }).nullish(),
    items: z
      .array(challanItemSchema)
      .nullish()
      .transform((v) => v ?? []),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
    archivedAt: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().optional(),
  })
  .passthrough();
export type Challan = z.infer<typeof challanSchema>;

export const challanListSchema = z.object({
  data: z
    .array(challanSchema)
    .nullish()
    .transform((v) => v ?? []),
  pagination: z
    .object({ total: z.coerce.number().default(0) })
    .nullish(),
});

export function challanItemCount(c: Challan): number {
  return c._count?.items ?? c.items.length;
}
