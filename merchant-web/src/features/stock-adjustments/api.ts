import { adjustmentListSchema, adjustmentSchema, type Adjustment } from "./schema";

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

export function listAdjustments(opts?: { reasonCode?: string }): Promise<Adjustment[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.reasonCode) qs.set("reasonCode", opts.reasonCode);
  return fetch(`/api/stock-adjustments?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => adjustmentListSchema.parse(raw).data, "Could not load adjustments."),
  );
}

export function getAdjustment(id: string): Promise<Adjustment> {
  return fetch(`/api/stock-adjustments/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => adjustmentSchema.parse(raw), "Could not load the adjustment."),
  );
}

export function createAdjustment(input: {
  reasonCode: string;
  direction: "IN" | "OUT";
  note?: string;
  items: { productId: string; quantity: number }[];
}): Promise<Adjustment> {
  return fetch("/api/stock-adjustments", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => adjustmentSchema.parse(raw), "Could not post the adjustment."));
}

export async function reverseAdjustment(id: string, note?: string): Promise<void> {
  const res = await fetch(`/api/stock-adjustments/${id}/reverse`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ note }),
  });
  if (!res.ok) await jsonOrThrow(res, () => null, "Could not reverse the adjustment.");
}
