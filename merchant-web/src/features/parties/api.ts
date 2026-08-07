import { ledgerSchema, type Ledger } from "@/shared/ledger";
import type { ContactWrite } from "@/shared/ui/contact-editor";
import {
  partyListSchema,
  partyOverviewSchema,
  partySchema,
  type Party,
  type PartyOverview,
} from "./schema";

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

export function listParties(opts?: { search?: string }): Promise<Party[]> {
  const qs = new URLSearchParams({ limit: "100" });
  if (opts?.search) qs.set("search", opts.search);
  return fetch(`/api/parties?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => partyListSchema.parse(raw).data, "Could not load customers."),
  );
}

export function getPartyOverview(id: string): Promise<PartyOverview> {
  return fetch(`/api/parties/${id}/overview`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => partyOverviewSchema.parse(raw), "Could not load the customer."),
  );
}

export function getPartyLedger(id: string): Promise<Ledger> {
  return fetch(`/api/parties/${id}/ledger`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => ledgerSchema.parse(raw), "Could not load the ledger."),
  );
}

export function getParty(id: string): Promise<Party> {
  return fetch(`/api/parties/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => partySchema.parse(raw), "Could not load the customer."),
  );
}

/** Drop null/empty optional fields — the backend create schema rejects null. */
function createBody(input: ContactWrite): Record<string, string> {
  const out: Record<string, string> = { name: input.name };
  for (const [k, v] of Object.entries(input)) {
    if (k === "name") continue;
    if (typeof v === "string" && v.trim() !== "") out[k] = v;
  }
  return out;
}

export function createParty(input: ContactWrite): Promise<Party> {
  return fetch("/api/parties", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(createBody(input)),
  }).then((r) => jsonOrThrow(r, (raw) => partySchema.parse(raw), "Could not create the customer."));
}

/**
 * Fill in a party's postal fields without touching anything else.
 *
 * `updateParty` sends a whole `ContactWrite`, so calling it with only the
 * address fields would blank the party's phone, GSTIN and the rest. This
 * re-reads the row first and merges, which is what the invoice form's
 * "also save to this customer" needs: complete what's missing, disturb nothing.
 */
export async function fillPartyAddress(
  id: string,
  address: Partial<
    Pick<ContactWrite, "address" | "city" | "state" | "stateCode" | "pinCode">
  >,
): Promise<void> {
  const current = await getParty(id);
  await updateParty(id, {
    name: current.name,
    contactName: current.contactName ?? null,
    phone: current.phone ?? null,
    email: current.email ?? null,
    panNumber: current.panNumber ?? null,
    gstin: current.gstin ?? null,
    // Only overwrite a field the merchant actually supplied.
    address: address.address ?? current.address ?? null,
    city: address.city ?? current.city ?? null,
    state: address.state ?? current.state ?? null,
    stateCode: address.stateCode ?? current.stateCode ?? null,
    pinCode: address.pinCode ?? current.pinCode ?? null,
  });
}

export async function updateParty(id: string, input: ContactWrite): Promise<void> {
  const res = await fetch(`/api/parties/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  await okOrThrow(res, "Could not update the customer.");
}

export async function deleteParty(id: string): Promise<void> {
  const res = await fetch(`/api/parties/${id}`, { method: "DELETE" });
  await okOrThrow(res, "Could not delete the customer.");
}
