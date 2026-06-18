import {
  saleSnapshotSchema,
  unknownScanSchema,
  ticketSchema,
  checkoutResultSchema,
  type SaleSnapshot,
  type TenderMode,
} from "./types";

async function call(path: string, init?: RequestInit): Promise<unknown> {
  const res = await fetch(path, {
    ...init,
    headers: init?.body ? { "Content-Type": "application/json" } : undefined,
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error((body as { error?: string } | null)?.error ?? "Request failed.");
  }
  return body;
}

const snap = (b: unknown): SaleSnapshot => saleSnapshotSchema.parse(b);

export const posApi = {
  /** Mint a POS-area WS ticket (works for invoices-only cashiers). */
  ticket: () => call("/api/pos/ticket", { method: "POST" }).then((b) => ticketSchema.parse(b)),

  open: (body?: { customerName?: string; customerPhone?: string }) =>
    call("/api/pos/sales", { method: "POST", body: JSON.stringify(body ?? {}) }).then(snap),

  get: (saleId: number) => call(`/api/pos/sales/${saleId}`).then(snap),

  /** Returns a snapshot, or `{ unknown, code }` when the scan matched nothing.
   * `opId` makes a retry idempotent (the server dedupes increments). */
  scan: async (saleId: number, code: string, opId?: string): Promise<SaleSnapshot | { unknown: true; code: string }> => {
    const body = await call(`/api/pos/sales/${saleId}/scan`, { method: "POST", body: JSON.stringify({ code, opId }) });
    const unknown = unknownScanSchema.safeParse(body);
    if (unknown.success) return unknown.data;
    return snap(body);
  },

  addItem: (saleId: number, productId: number, quantity = 1) =>
    call(`/api/pos/sales/${saleId}/items`, { method: "POST", body: JSON.stringify({ productId, quantity }) }).then(snap),

  patchItem: (saleId: number, productId: number, patch: { quantity?: number; lineDiscount?: number; unitPrice?: number }) =>
    call(`/api/pos/sales/${saleId}/items/${productId}`, { method: "PATCH", body: JSON.stringify(patch) }).then(snap),

  removeItem: (saleId: number, productId: number) =>
    call(`/api/pos/sales/${saleId}/items/${productId}`, { method: "DELETE" }).then(snap),

  quickAdd: (
    saleId: number,
    input: { code: string; name: string; sellingPrice: number; taxPercent?: number; openingStock?: number },
  ) => call(`/api/pos/sales/${saleId}/quick-add`, { method: "POST", body: JSON.stringify(input) }).then(snap),

  setHeaderDiscount: (saleId: number, headerDiscount: number) =>
    call(`/api/pos/sales/${saleId}`, { method: "PATCH", body: JSON.stringify({ headerDiscount }) }).then(snap),

  checkout: (saleId: number, tender: { mode: TenderMode; modeReference?: string }) =>
    call(`/api/pos/sales/${saleId}/checkout`, { method: "POST", body: JSON.stringify({ tender }) }).then((b) =>
      checkoutResultSchema.parse(b),
    ),
};
