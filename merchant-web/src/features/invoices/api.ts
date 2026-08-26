import { invoiceListSchema, invoiceSchema, type Invoice } from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

async function okOrThrow(res: Response, fallback: string): Promise<void> {
  if (res.ok || res.status === 204) return;
  await jsonOrThrow(res, () => null, fallback);
}

export type InvoiceListFilters = {
  type?: string;
  status?: string;
  documentType?: string;
  search?: string;
  vendorId?: string;
  partyId?: string;
  productId?: string;
  archived?: boolean;
};

export function listInvoices(filters: InvoiceListFilters): Promise<Invoice[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (filters.type) qs.set("type", filters.type);
  if (filters.status) qs.set("status", filters.status);
  if (filters.documentType) qs.set("documentType", filters.documentType);
  if (filters.search) qs.set("search", filters.search);
  if (filters.vendorId) qs.set("vendorId", String(filters.vendorId));
  if (filters.partyId) qs.set("partyId", String(filters.partyId));
  if (filters.productId) qs.set("productId", String(filters.productId));
  if (filters.archived) qs.set("archived", "true");
  return fetch(`/api/invoices?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => invoiceListSchema.parse(raw).data, "Could not load invoices."),
  );
}

export function getInvoice(id: string): Promise<Invoice> {
  return fetch(`/api/invoices/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => invoiceSchema.parse(raw), "Could not load the invoice."),
  );
}

export type InvoiceItemWrite = {
  productId: string;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  isPriceInclusive?: boolean;
  discount?: number;
};

export type InvoiceWrite = {
  type: "SALE" | "PURCHASE";
  documentType?: string;
  placeOfSupplyStateCode?: string;
  partyId?: string;
  vendorId?: string;
  customerName?: string;
  customerPhone?: string;
  customerGstin?: string;
  discount?: number;
  note?: string;
  items: InvoiceItemWrite[];
  confirm?: boolean;
};

export type CreateInvoiceResult = {
  invoice: Invoice;
  confirmed: boolean;
  confirmError?: string;
};

export async function createInvoice(input: InvoiceWrite): Promise<CreateInvoiceResult> {
  const res = await fetch("/api/invoices", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  const raw = await jsonOrThrow<{ confirmed?: boolean; confirmError?: string }>(
    res,
    (r) => r as { confirmed?: boolean; confirmError?: string },
    "Could not create the invoice.",
  );
  return {
    invoice: invoiceSchema.parse(raw),
    confirmed: raw.confirmed ?? false,
    confirmError: raw.confirmError,
  };
}

export function updateInvoice(id: string, input: InvoiceWrite): Promise<Invoice> {
  return fetch(`/api/invoices/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => invoiceSchema.parse(raw), "Could not save the invoice."));
}

export function updateInvoiceStatus(id: string, status: "CONFIRMED" | "CANCELLED"): Promise<Invoice> {
  return fetch(`/api/invoices/${id}/status`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status }),
  }).then((r) => jsonOrThrow(r, (raw) => invoiceSchema.parse(raw), "Could not update the invoice."));
}

export function convertEstimate(id: string): Promise<Invoice> {
  return fetch(`/api/invoices/${id}/convert`, { method: "POST" }).then((r) =>
    jsonOrThrow(r, (raw) => invoiceSchema.parse(raw), "Could not convert to an invoice."),
  );
}

export async function setInvoiceArchived(
  id: string,
  archived: boolean,
): Promise<void> {
  const res = await fetch(
    `/api/invoices/${id}/archive${archived ? "" : "?restore=1"}`,
    { method: "POST" },
  );
  await okOrThrow(
    res,
    archived
      ? "Could not archive the invoice."
      : "Could not restore the invoice.",
  );
}

export function invoicePdfUrl(id: string): string {
  return `/api/invoices/${id}/pdf`;
}
