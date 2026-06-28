import {
  gstReportSchema,
  pnlReportSchema,
  purchasesReportSchema,
  salesReportSchema,
  soldItemsPageSchema,
  soldProductsPageSchema,
  type GstReport,
  type PnlReport,
  type PurchasesReport,
  type SalesReport,
  type SoldItemsPage,
  type SoldProductsPage,
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

export type Range = { from: string; to: string };

function qs(range: Range): string {
  return new URLSearchParams({ from: range.from, to: range.to }).toString();
}

export function getSalesReport(range: Range): Promise<SalesReport> {
  return fetch(`/api/reports/sales?${qs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => salesReportSchema.parse(raw), "Could not load the sales report."),
  );
}

export function getPurchasesReport(range: Range): Promise<PurchasesReport> {
  return fetch(`/api/reports/purchases?${qs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => purchasesReportSchema.parse(raw), "Could not load the purchases report."),
  );
}

export function getGstReport(range: Range): Promise<GstReport> {
  return fetch(`/api/reports/gst?${qs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => gstReportSchema.parse(raw), "Could not load the GST report."),
  );
}

export function getPnlReport(range: Range): Promise<PnlReport> {
  return fetch(`/api/reports/pnl?${qs(range)}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => pnlReportSchema.parse(raw), "Could not load the P&L report."),
  );
}

/** Aggregated "products sold" summary — one row per product, biggest revenue
 *  first, optionally filtered by a product name / SKU search. */
export function getSoldProducts(
  range: Range,
  page = 1,
  limit = 25,
  search = "",
): Promise<SoldProductsPage> {
  const params = new URLSearchParams({
    from: range.from,
    to: range.to,
    page: String(page),
    limit: String(limit),
  });
  if (search.trim()) params.set("search", search.trim());
  return fetch(`/api/reports/sold-products?${params.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => soldProductsPageSchema.parse(raw), "Could not load sold products."),
  );
}

/** One page of a single product's sale timeline (newest first). */
export function getSoldItems(
  range: Range,
  productId: number,
  page = 1,
  limit = 25,
): Promise<SoldItemsPage> {
  const params = new URLSearchParams({
    from: range.from,
    to: range.to,
    productId: String(productId),
    page: String(page),
    limit: String(limit),
  });
  return fetch(`/api/reports/sold-items?${params.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => soldItemsPageSchema.parse(raw), "Could not load the sale timeline."),
  );
}
