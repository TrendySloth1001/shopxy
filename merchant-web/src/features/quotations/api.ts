import { quotationListSchema, quotationSchema, type Quotation } from "./schema";

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

export function listQuotations(opts?: { status?: string }): Promise<Quotation[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.status) qs.set("status", opts.status);
  return fetch(`/api/quotations?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationListSchema.parse(raw).data, "Could not load quotations."),
  );
}

export function getQuotation(id: number): Promise<Quotation> {
  return fetch(`/api/quotations/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not load the quotation."),
  );
}

/** Line item as sent to create / respond. */
export type QuotationItemWrite = {
  productId: number;
  name: string;
  sku?: string;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  discount?: number;
  imageUrl?: string;
};

export function createQuotation(input: {
  partyId: number;
  items: QuotationItemWrite[];
  note?: string;
  placeOfSupplyStateCode?: string;
}): Promise<Quotation> {
  return fetch("/api/quotations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not send the quotation."));
}

export function respondQuotation(
  id: number,
  input: { items: QuotationItemWrite[]; note?: string; placeOfSupplyStateCode?: string },
): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/respond`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not send the quotation."));
}

export function cancelQuotation(id: number): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/cancel`, { method: "POST" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not cancel the quotation."),
  );
}

export function declineQuotationRequest(id: number, declineNote?: string): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/decline-request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ declineNote }),
  }).then((r) => jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not decline the request."));
}

export function quotationPdfUrl(id: number): string {
  return `/api/quotations/${id}/pdf`;
}
