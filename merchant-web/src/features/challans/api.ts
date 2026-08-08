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

export function listChallans(opts?: {
  status?: string;
  search?: string;
  /** The "Archived" view. Archived challans are out of every other list. */
  archived?: boolean;
}): Promise<Challan[]> {
  const qs = new URLSearchParams({ limit: "50" });
  if (opts?.status) qs.set("status", opts.status);
  if (opts?.search) qs.set("search", opts.search);
  if (opts?.archived) qs.set("archived", "true");
  return fetch(`/api/challans?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => challanListSchema.parse(raw).data, "Could not load challans."),
  );
}

export function getChallan(id: string): Promise<Challan> {
  return fetch(`/api/challans/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => challanSchema.parse(raw), "Could not load the challan."),
  );
}

export function createChallan(input: {
  partyId?: string;
  partyName?: string;
  partyPhone?: string;
  note?: string;
  items: { productId: string; quantity: number }[];
}): Promise<Challan> {
  return fetch("/api/challans", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => challanSchema.parse(raw), "Could not create the challan."));
}

export async function cancelChallan(id: string): Promise<void> {
  const res = await fetch(`/api/challans/${id}/cancel`, { method: "PATCH" });
  await okOrThrow(res, "Could not cancel the challan.");
}

/**
 * File a settled challan out of the working list, or bring it back.
 *
 * There is no delete: the challan number is allocated at create time and
 * Rule 55 wants the run serially numbered. The backend refuses a PENDING
 * challan — goods are still out against it.
 */
export function setChallanArchived(id: string, archived: boolean): Promise<Challan> {
  const qs = archived ? "" : "?restore=1";
  return fetch(`/api/challans/${id}/archive${qs}`, { method: "POST" }).then((r) =>
    jsonOrThrow(
      r,
      (raw) => challanSchema.parse(raw),
      archived ? "Could not archive the challan." : "Could not restore the challan.",
    ),
  );
}

/** Convert a PENDING challan into a draft SALE invoice; returns the new id. */
export function convertChallan(
  id: string,
  input?: { customerName?: string; customerGstin?: string; discount?: number; note?: string },
): Promise<{ id: string }> {
  return fetch(`/api/challans/${id}/convert`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input ?? {}),
  }).then((r) =>
    jsonOrThrow(
      r,
      (raw) => {
        const obj = raw as { id?: string };
        if (typeof obj?.id !== "number") throw new Error("Could not convert the challan.");
        return { id: obj.id };
      },
      "Could not convert the challan.",
    ),
  );
}
