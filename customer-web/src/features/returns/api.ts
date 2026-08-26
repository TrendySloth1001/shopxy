import { returnsPageSchema, returnRequestSchema, type ReturnsPage, type ReturnRequest } from "./types";

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
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchReturns(opts?: {
  page?: number;
  limit?: number;
}): Promise<ReturnsPage> {
  const qs = new URLSearchParams({
    page: String(opts?.page ?? 1),
    limit: String(opts?.limit ?? 20),
  });
  const res = await fetch(`/api/me/returns?${qs}`, { cache: "no-store" });
  return jsonOrThrow(res, (raw) => returnsPageSchema.parse(raw), "Could not load returns.");
}

export async function fetchReturnDetail(id: string): Promise<ReturnRequest> {
  const res = await fetch(`/api/me/returns/${id}`, { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => returnRequestSchema.parse(raw),
    "Could not load return.",
  );
}

export async function cancelReturn(id: string): Promise<void> {
  const res = await fetch(`/api/me/returns/${id}/cancel`, { method: "POST" });
  if (!res.ok) {
    let message = "Could not cancel return.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
}

export async function submitReturn(
  parentOrderId: string,
  body: {
    childId: string;
    note?: string;
    items: Array<{ purchaseRequestItemId: string; quantity: number; reason: string }>;
  },
): Promise<{ id: string }> {
  const res = await fetch(`/api/me/orders/${parentOrderId}/returns`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return jsonOrThrow(
    res,
    (raw) => raw as { id: string },
    "Could not submit return request.",
  );
}
