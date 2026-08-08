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

export function listQuotations(opts?: {
  status?: string;
  /** The "Archived" view. Archived quotes are out of every other merchant list. */
  archived?: boolean;
}): Promise<Quotation[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.status) qs.set("status", opts.status);
  if (opts?.archived) qs.set("archived", "true");
  return fetch(`/api/quotations?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationListSchema.parse(raw).data, "Could not load quotations."),
  );
}

export function getQuotation(id: string): Promise<Quotation> {
  return fetch(`/api/quotations/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not load the quotation."),
  );
}

/** Line item as sent to create / respond. */
export type QuotationItemWrite = {
  productId: string;
  name: string;
  sku?: string;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  isPriceInclusive?: boolean;
  discount?: number;
  imageUrl?: string;
};

export function createQuotation(input: {
  partyId: string;
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
  id: string,
  input: { items: QuotationItemWrite[]; note?: string; placeOfSupplyStateCode?: string },
): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/respond`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not send the quotation."));
}

export function cancelQuotation(id: string): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/cancel`, { method: "POST" }).then((r) =>
    jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not cancel the quotation."),
  );
}

/**
 * File a settled quotation out of the merchant's working list, or bring it
 * back. The backend refuses one the customer can still act on (REQUESTED /
 * PENDING). Merchant-side only — the customer keeps seeing it.
 */
export function setQuotationArchived(id: string, archived: boolean): Promise<Quotation> {
  const qs = archived ? "" : "?restore=1";
  return fetch(`/api/quotations/${id}/archive${qs}`, { method: "POST" }).then((r) =>
    jsonOrThrow(
      r,
      (raw) => quotationSchema.parse(raw),
      archived ? "Could not archive the quotation." : "Could not restore the quotation.",
    ),
  );
}

export function declineQuotationRequest(id: string, declineNote?: string): Promise<Quotation> {
  return fetch(`/api/quotations/${id}/decline-request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ declineNote }),
  }).then((r) => jsonOrThrow(r, (raw) => quotationSchema.parse(raw), "Could not decline the request."));
}

export function quotationPdfUrl(id: string): string {
  return `/api/quotations/${id}/pdf`;
}
