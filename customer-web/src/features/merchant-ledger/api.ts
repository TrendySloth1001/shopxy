/**
 * Client-side fetchers for the merchant-ledger feature.
 * All calls go to /api/me/{parties|vendors}/** (BFF proxies to backend).
 */
import {
  invoicesPageSchema,
  invoiceDetailSchema,
  quotationsPageSchema,
  quotationSchema,
  catalogPageSchema,
  type InvoicesPage,
  type InvoiceDetail,
  type QuotationsPage,
  type Quotation,
  type CatalogPage,
  type MerchantRole,
  type BasketItem,
} from "./types";

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

/** Base path: /api/me/parties/:id  or  /api/me/vendors/:id */
function basePath(role: MerchantRole, id: string): string {
  return `/api/me/${role === "party" ? "parties" : "vendors"}/${encodeURIComponent(id)}`;
}

// ─── Invoices ────────────────────────────────────────────────────────────────

export async function fetchInvoices(
  role: MerchantRole,
  id: string,
  opts?: { page?: number; limit?: number },
): Promise<InvoicesPage> {
  const qs = new URLSearchParams({
    page: String(opts?.page ?? 1),
    limit: String(opts?.limit ?? 30),
  });
  const res = await fetch(`${basePath(role, id)}/invoices?${qs}`, {
    cache: "no-store",
  });
  return jsonOrThrow(res, (raw) => invoicesPageSchema.parse(raw), "Could not load invoices.");
}

export async function fetchInvoiceDetail(
  role: MerchantRole,
  id: string,
  invoiceId: string,
): Promise<InvoiceDetail> {
  const res = await fetch(
    `${basePath(role, id)}/invoices/${encodeURIComponent(invoiceId)}`,
    { cache: "no-store" },
  );
  return jsonOrThrow(res, (raw) => invoiceDetailSchema.parse(raw), "Could not load invoice.");
}

/** Returns a BFF URL safe for <a href> / window.open */
export function invoicePdfUrl(role: MerchantRole, id: string, invoiceId: string): string {
  return `${basePath(role, id)}/invoices/${encodeURIComponent(invoiceId)}/pdf`;
}

// ─── Quotations ──────────────────────────────────────────────────────────────

export async function fetchQuotations(
  partyId: string,
  opts?: { page?: number; limit?: number },
): Promise<QuotationsPage> {
  const qs = new URLSearchParams({
    page: String(opts?.page ?? 1),
    limit: String(opts?.limit ?? 30),
  });
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations?${qs}`,
    { cache: "no-store" },
  );
  return jsonOrThrow(res, (raw) => quotationsPageSchema.parse(raw), "Could not load quotations.");
}

export async function fetchQuotationDetail(partyId: string, quotationId: string): Promise<Quotation> {
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}`,
    { cache: "no-store" },
  );
  return jsonOrThrow(res, (raw) => quotationSchema.parse(raw), "Could not load quotation.");
}

export async function acceptQuotation(partyId: string, quotationId: number): Promise<Quotation> {
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(String(quotationId))}/accept`,
    { method: "POST" },
  );
  return jsonOrThrow(res, (raw) => quotationSchema.parse(raw), "Could not accept quotation.");
}

export async function declineQuotation(
  partyId: string,
  quotationId: number,
  payload?: { declineNote?: string },
): Promise<Quotation> {
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(String(quotationId))}/decline`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload ?? {}),
    },
  );
  return jsonOrThrow(res, (raw) => quotationSchema.parse(raw), "Could not decline quotation.");
}

export async function cancelQuotation(partyId: string, quotationId: number): Promise<Quotation> {
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(String(quotationId))}/cancel`,
    { method: "POST" },
  );
  return jsonOrThrow(res, (raw) => quotationSchema.parse(raw), "Could not withdraw quotation.");
}

export async function requestQuotation(
  partyId: string,
  payload: { items: BasketItem[]; note?: string },
): Promise<Quotation> {
  const res = await fetch(
    `/api/me/parties/${encodeURIComponent(partyId)}/quotations`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    },
  );
  return jsonOrThrow(res, (raw) => quotationSchema.parse(raw), "Could not send quote request.");
}

/** Returns a BFF URL for quotation PDF download */
export function quotationPdfUrl(partyId: string, quotationId: number): string {
  return `/api/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(String(quotationId))}/pdf`;
}

// ─── Catalog (for request-quote page) ────────────────────────────────────────

export async function fetchCatalogProducts(
  opts?: { search?: string; categoryId?: number; page?: number; limit?: number },
): Promise<CatalogPage> {
  const qs = new URLSearchParams({ page: String(opts?.page ?? 1), limit: String(opts?.limit ?? 100) });
  if (opts?.search) qs.set("search", opts.search);
  if (opts?.categoryId != null) qs.set("categoryId", String(opts.categoryId));
  const res = await fetch(`/api/me/catalog/products?${qs}`, { cache: "no-store" });
  return jsonOrThrow(res, (raw) => catalogPageSchema.parse(raw), "Could not load catalogue.");
}
