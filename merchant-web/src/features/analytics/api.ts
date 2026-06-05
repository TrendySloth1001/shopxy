import { productAnalyticsSchema, type ProductAnalytics } from "./schema";

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

export function getProductAnalytics(range: { from: string; to: string }): Promise<ProductAnalytics> {
  const qs = new URLSearchParams({ from: range.from, to: range.to, limit: "200" });
  return fetch(`/api/analytics/products?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => productAnalyticsSchema.parse(raw), "Could not load analytics."),
  );
}
