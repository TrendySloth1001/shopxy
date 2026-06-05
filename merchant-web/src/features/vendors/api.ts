import { ledgerSchema, type Ledger } from "@/shared/ledger";
import type { ContactWrite } from "@/shared/ui/contact-editor";
import {
  vendorListSchema,
  vendorOverviewSchema,
  vendorSchema,
  type Vendor,
  type VendorOverview,
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

export function listVendors(opts?: { search?: string }): Promise<Vendor[]> {
  const qs = new URLSearchParams({ limit: "100" });
  if (opts?.search) qs.set("search", opts.search);
  return fetch(`/api/vendors?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => vendorListSchema.parse(raw).data, "Could not load vendors."),
  );
}

export function getVendorOverview(id: number): Promise<VendorOverview> {
  return fetch(`/api/vendors/${id}/overview`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => vendorOverviewSchema.parse(raw), "Could not load the vendor."),
  );
}

export function getVendorLedger(id: number): Promise<Ledger> {
  return fetch(`/api/vendors/${id}/ledger`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => ledgerSchema.parse(raw), "Could not load the ledger."),
  );
}

export function getVendor(id: number): Promise<Vendor> {
  return fetch(`/api/vendors/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => vendorSchema.parse(raw), "Could not load the vendor."),
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

export function createVendor(input: ContactWrite): Promise<Vendor> {
  return fetch("/api/vendors", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(createBody(input)),
  }).then((r) => jsonOrThrow(r, (raw) => vendorSchema.parse(raw), "Could not create the vendor."));
}

export async function updateVendor(id: number, input: ContactWrite): Promise<void> {
  const res = await fetch(`/api/vendors/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  await okOrThrow(res, "Could not update the vendor.");
}

export async function deleteVendor(id: number): Promise<void> {
  const res = await fetch(`/api/vendors/${id}`, { method: "DELETE" });
  await okOrThrow(res, "Could not delete the vendor.");
}
