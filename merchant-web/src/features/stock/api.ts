import {
  stockDraftSchema,
  stockTxnListSchema,
  suppliersResponseSchema,
  type CreateStockInput,
  type StockDraft,
  type StockTxn,
  type StockType,
  type SuppliersResponse,
} from "./schema";

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

export function listSuppliers(opts?: {
  productId?: string;
  q?: string;
  limit?: number;
}): Promise<SuppliersResponse> {
  const qs = new URLSearchParams({ limit: String(opts?.limit ?? 20) });
  if (opts?.productId) qs.set("productId", String(opts.productId));
  if (opts?.q) qs.set("q", opts.q);
  return fetch(`/api/stock/suppliers?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => suppliersResponseSchema.parse(raw), "Could not load suppliers."),
  );
}

export function listStockTransactions(opts: {
  productId: string;
  type?: StockType;
  limit?: number;
}): Promise<StockTxn[]> {
  const qs = new URLSearchParams({
    productId: String(opts.productId),
    limit: String(opts.limit ?? 100),
  });
  if (opts.type) qs.set("type", opts.type);
  return fetch(`/api/stock?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(
      r,
      (raw) => stockTxnListSchema.parse(raw).data,
      "Could not load purchase history.",
    ),
  );
}

export function createStockTransaction(input: CreateStockInput): Promise<StockDraft> {
  return fetch("/api/stock", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) =>
    jsonOrThrow(r, (raw) => stockDraftSchema.parse(raw), "Could not record the stock movement."),
  );
}
