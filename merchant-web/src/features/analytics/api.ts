import {
  heatmapSchema,
  productAnalyticsSchema,
  retentionSchema,
  type Heatmap,
  type ProductAnalytics,
  type Retention,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

type Range = { from: string; to: string };
const rangeQs = (r: Range) => new URLSearchParams({ from: r.from, to: r.to }).toString();

export function getProductAnalytics(
  range: Range,
  opts?: { limit?: number; cursor?: string | null },
): Promise<ProductAnalytics> {
  const qs = new URLSearchParams({ from: range.from, to: range.to, limit: String(opts?.limit ?? 100) });
  if (opts?.cursor) qs.set("cursor", opts.cursor);
  return fetch(`/api/analytics/products?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => productAnalyticsSchema.parse(raw), "Could not load analytics."),
  );
}

export function getPurchaseHeatmap(range: Range): Promise<Heatmap> {
  return fetch(`/api/analytics/heatmap?${rangeQs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => heatmapSchema.parse(raw), "Could not load the heatmap."),
  );
}

export function getCustomerRetention(range: Range): Promise<Retention> {
  return fetch(`/api/analytics/customers?${rangeQs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => retentionSchema.parse(raw), "Could not load customers."),
  );
}
