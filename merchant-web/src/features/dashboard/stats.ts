import { z } from "zod";

/**
 * Dashboard payload, mirroring the backend `GET /dashboard/stats?period=…`
 * response (`backend/src/modules/dashboard/dashboard.service.ts`). Money
 * sections (`kpis`, `trend`, `insights`, `operations.gstMtd`) are null unless
 * the caller holds `reports:view`. Decimal money/qty fields are coerced to
 * numbers; validated at the BFF boundary so the screen gets a clean typed object.
 */

export const PERIODS = ["today", "week", "month"] as const;
export type DashboardPeriod = (typeof PERIODS)[number];

export const PERIOD_LABEL: Record<DashboardPeriod, string> = {
  today: "Today",
  week: "7 days",
  month: "30 days",
};

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
    product: z.object({ name: z.string().nullable().optional() }).nullable().optional(),
  })
  .passthrough();

const kpiMoneySchema = z.object({
  value: z.coerce.number().default(0),
  prev: z.coerce.number().default(0),
  deltaPct: z.number().nullable().default(null),
});

const tillSchema = z
  .object({
    shiftId: z.number(),
    openedAt: z.string(),
    salesCount: z.coerce.number().default(0),
    salesGross: z.coerce.number().default(0),
    expectedCash: z.coerce.number().default(0),
    tenders: z
      .array(
        z.object({
          mode: z.string(),
          amount: z.coerce.number().default(0),
          count: z.coerce.number().default(0),
        }),
      )
      .default([]),
  })
  .nullable()
  .default(null);

const gstMtdSchema = z
  .object({
    monthStart: z.string(),
    outputTax: z.coerce.number().default(0),
    inputTax: z.coerce.number().default(0),
    netPayable: z.coerce.number().default(0),
  })
  .nullable()
  .default(null);

const kpisSchema = z
  .object({
    sales: kpiMoneySchema,
    profit: kpiMoneySchema.extend({ margin: z.coerce.number().default(0) }),
    receivables: z.object({
      outstanding: z.coerce.number().default(0),
      debtors: z.number().default(0),
    }),
    payables: z.object({
      outstanding: z.coerce.number().default(0),
      creditors: z.number().default(0),
    }),
  })
  .nullable()
  .default(null);

const numArray = z.array(z.coerce.number()).default([]);

const trendSchema = z
  .object({
    labels: z.array(z.string()).default([]),
    sales: numArray,
    previous: numArray,
    purchases: numArray,
    returns: numArray,
    paymentSeries: z
      .array(z.object({ mode: z.string(), values: numArray }))
      .default([]),
  })
  .nullable()
  .default(null);

const insightsSchema = z
  .object({
    topProducts: z
      .array(
        z.object({
          name: z.string(),
          revenue: z.coerce.number().default(0),
          quantity: z.coerce.number().default(0),
        }),
      )
      .default([]),
    topCategories: z
      .array(z.object({ name: z.string(), revenue: z.coerce.number().default(0) }))
      .default([]),
    slowMovers: z
      .array(
        z.object({
          name: z.string(),
          stock: z.coerce.number().default(0),
          sold: z.coerce.number().default(0),
        }),
      )
      .default([]),
  })
  .nullable()
  .default(null);

const alertSchema = z.object({
  id: z.string(),
  severity: z.enum(["critical", "warning", "info"]).catch("info"),
  message: z.string(),
  href: z.string(),
});

export const dashboardStatsSchema = z.object({
  meta: z.object({
    period: z.enum(PERIODS).catch("today"),
    from: z.string(),
    to: z.string(),
  }),
  onboarding: z.object({
    totalProducts: z.number().default(0),
    activeProducts: z.number().default(0),
    hasInvoices: z.boolean().default(false),
    hasParties: z.boolean().default(false),
  }),
  actionQueue: z.object({
    orders: z.number().default(0),
    quotations: z.number().default(0),
    returns: z.number().default(0),
    drafts: z.number().default(0),
    lowStock: z.number().default(0),
    outOfStock: z.number().default(0),
  }),
  operations: z.object({
    inventoryValue: z.coerce.number().default(0),
    till: tillSchema,
    gstMtd: gstMtdSchema,
  }),
  alerts: z.array(alertSchema).default([]),
  recent: z.array(transactionSchema).default([]),
  kpis: kpisSchema,
  trend: trendSchema,
  insights: insightsSchema,
});

export type DashboardStats = z.infer<typeof dashboardStatsSchema>;
export type DashboardTransaction = z.infer<typeof transactionSchema>;
export type DashboardKpis = NonNullable<z.infer<typeof kpisSchema>>;
export type DashboardTrend = NonNullable<z.infer<typeof trendSchema>>;
export type DashboardInsights = NonNullable<z.infer<typeof insightsSchema>>;
export type DashboardTill = NonNullable<z.infer<typeof tillSchema>>;
export type DashboardGstMtd = NonNullable<z.infer<typeof gstMtdSchema>>;
export type DashboardAlert = z.infer<typeof alertSchema>;
export type DashboardActionQueue = DashboardStats["actionQueue"];
export type DashboardOnboarding = DashboardStats["onboarding"];

function isPeriod(value: string): value is DashboardPeriod {
  return (PERIODS as readonly string[]).includes(value);
}

/** Client-side fetch of the dashboard stats via the BFF for a given period. */
export async function fetchDashboardStats(period: DashboardPeriod): Promise<DashboardStats> {
  const safe = isPeriod(period) ? period : "today";
  const res = await fetch(`/api/dashboard/stats?period=${safe}`, { cache: "no-store" });
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
