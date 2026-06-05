import {
  gstReportSchema,
  pnlReportSchema,
  purchasesReportSchema,
  salesReportSchema,
  type GstReport,
  type PnlReport,
  type PurchasesReport,
  type SalesReport,
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
