import { refundResultSchema, returnListSchema, returnSchema, type MerchantReturn, type RefundResult } from "./schema";

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

async function okOrThrow(res: Response, fallback: string): Promise<void> {
  if (res.ok || res.status === 204) return;
  await jsonOrThrow(res, () => null, fallback);
}

export function listReturns(opts?: { status?: string }): Promise<MerchantReturn[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.status) qs.set("status", opts.status);
  return fetch(`/api/returns?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => returnListSchema.parse(raw).data, "Could not load returns."),
  );
}

export function getReturn(id: string): Promise<MerchantReturn> {
  return fetch(`/api/returns/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => returnSchema.parse(raw), "Could not load the return."),
  );
}

async function postAction(id: string, action: string, body: Record<string, unknown>, fallback: string): Promise<void> {
  const res = await fetch(`/api/returns/${id}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  await okOrThrow(res, fallback);
}

export function approveReturn(id: string, note?: string): Promise<void> {
  return postAction(id, "approve", { note }, "Could not approve the return.");
}
export function rejectReturn(id: string, note: string): Promise<void> {
  return postAction(id, "reject", { note }, "Could not reject the return.");
}
export function markPickedUp(id: string): Promise<void> {
  return postAction(id, "picked-up", {}, "Could not update the return.");
}
export function markReceived(id: string): Promise<void> {
  return postAction(id, "received", {}, "Could not update the return.");
}
/**
 * Refund a received return. The backend refunds to the buyer's ORIGINAL payment
 * method (gateway refund-to-source) — never a wallet — and replies with
 * `{ ok, refundAmount, refundStatus }`.
 */
export async function refundReturn(id: string, note?: string): Promise<RefundResult> {
  const res = await fetch(`/api/returns/${id}/refund`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ note }),
  });
  return jsonOrThrow(res, (raw) => refundResultSchema.parse(raw), "Could not refund the return.");
}
