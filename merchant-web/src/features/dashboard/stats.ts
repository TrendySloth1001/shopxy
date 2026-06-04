import { z } from "zod";

/**
 * Dashboard stats, mirroring the backend `GET /dashboard/stats` response
 * (`backend/src/modules/dashboard/dashboard.service.ts`). Decimal money/qty
 * fields are coerced to numbers; unknown fields pass through. Validated at the
 * BFF boundary so the screen works with a clean, typed object.
 */
const transactionSchema = z
  .object({
    id: z.number(),
    productId: z.number(),
    type: z.string().optional(),
    direction: z.string().optional(),
    quantity: z.coerce.number().default(0),
    sourceType: z.string().nullable().optional(),
    sourceId: z.number().nullable().optional(),
    createdAt: z.string(),
    product: z
      .object({ name: z.string().nullable().optional() })
      .nullable()
      .optional(),
  })
  .passthrough();

const draftSchema = z
  .object({
    id: z.number(),
    invoiceNo: z.string(),
    type: z.string(),
    total: z.coerce.number().default(0),
    customerName: z.string().nullable().optional(),
    vendorName: z.string().nullable().optional(),
    createdAt: z.string(),
    _count: z.object({ items: z.number() }).partial().nullable().optional(),
  })
  .passthrough();

export const dashboardStatsSchema = z.object({
  totalProducts: z.number().default(0),
  activeProducts: z.number().default(0),
  totalCategories: z.number().default(0),
  lowStockCount: z.number().default(0),
  outOfStockCount: z.number().default(0),
  totalStockValue: z.coerce.number().default(0),
  recentTransactions: z.array(transactionSchema).default([]),
  draftInvoices: z
    .object({
      count: z.number().default(0),
      recent: z.array(draftSchema).default([]),
    })
    .default({ count: 0, recent: [] }),
});

export type DashboardStats = z.infer<typeof dashboardStatsSchema>;
export type DashboardTransaction = z.infer<typeof transactionSchema>;
export type DashboardDraft = z.infer<typeof draftSchema>;

/** Client-side fetch of the dashboard stats via the BFF. */
export async function fetchDashboardStats(): Promise<DashboardStats> {
  const res = await fetch("/api/dashboard/stats", { cache: "no-store" });
  if (!res.ok) {
    let message = "Could not load the dashboard.";
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      // keep default
    }
    throw new Error(message);
  }
  return (await res.json()) as DashboardStats;
}
