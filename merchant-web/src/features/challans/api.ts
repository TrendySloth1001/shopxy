import { challanListSchema, challanSchema, type Challan } from "./schema";

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

export function listChallans(opts?: { status?: string; search?: string }): Promise<Challan[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.status) qs.set("status", opts.status);
  if (opts?.search) qs.set("search", opts.search);
  return fetch(`/api/challans?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => challanListSchema.parse(raw).data, "Could not load challans."),
  );
}

export function getChallan(id: number): Promise<Challan> {
  return fetch(`/api/challans/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => challanSchema.parse(raw), "Could not load the challan."),
  );
}

export function createChallan(input: {
  partyId?: number;
  partyName?: string;
  partyPhone?: string;
  note?: string;
  items: { productId: number; quantity: number }[];
}): Promise<Challan> {
  return fetch("/api/challans", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => challanSchema.parse(raw), "Could not create the challan."));
}

export async function cancelChallan(id: number): Promise<void> {
  const res = await fetch(`/api/challans/${id}/cancel`, { method: "PATCH" });
  await okOrThrow(res, "Could not cancel the challan.");
}

/** Convert a PENDING challan into a draft SALE invoice; returns the new id. */
export function convertChallan(
  id: number,
  input?: { customerName?: string; customerGstin?: string; discount?: number; note?: string },
): Promise<{ id: number }> {
  return fetch(`/api/challans/${id}/convert`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input ?? {}),
  }).then((r) =>
    jsonOrThrow(
      r,
      (raw) => {
        const obj = raw as { id?: number };
        if (typeof obj?.id !== "number") throw new Error("Could not convert the challan.");
        return { id: obj.id };
      },
      "Could not convert the challan.",
    ),
  );
}
