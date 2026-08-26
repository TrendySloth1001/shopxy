import { INDIAN_STATES } from "@/shared/india";

export type PosSource =
  | "partyGstin"
  | "partyAddress"
  | "vendorGstin"
  | "vendorAddress"
  | "shopDefault"
  | "manual";

export type PlaceOfSupply = { code: string | null; source: PosSource };

export function stateCodeFromGstin(
  gstin: string | null | undefined,
): string | null {
  const trimmed = (gstin ?? "").trim();
  if (trimmed.length < 2) return null;
  const prefix = trimmed.slice(0, 2);
  return INDIAN_STATES.some((s) => s.code === prefix) ? prefix : null;
}

type Counterparty = {
  stateCode?: string | null;
  gstin?: string | null;
} | null;

export function derivePlaceOfSupply(args: {
  type: "SALE" | "PURCHASE";
  party: Counterparty;
  vendor: Counterparty;
  typedGstin?: string | null;
  shopStateCode?: string | null;
}): PlaceOfSupply {
  const { type, party, vendor, typedGstin, shopStateCode } = args;

  if (type === "SALE") {
    if (party?.stateCode) return { code: party.stateCode, source: "partyAddress" };
    const fromPartyGstin = stateCodeFromGstin(party?.gstin);
    if (fromPartyGstin) return { code: fromPartyGstin, source: "partyGstin" };
    const fromTyped = stateCodeFromGstin(typedGstin);
    if (fromTyped) return { code: fromTyped, source: "partyGstin" };
    return { code: shopStateCode ?? null, source: "shopDefault" };
  }

  if (vendor?.stateCode) return { code: vendor.stateCode, source: "vendorAddress" };
  const fromVendorGstin = stateCodeFromGstin(vendor?.gstin);
  if (fromVendorGstin) return { code: fromVendorGstin, source: "vendorGstin" };
  return { code: shopStateCode ?? null, source: "shopDefault" };
}

export function canOverridePlaceOfSupply(source: PosSource): boolean {
  return source === "shopDefault" || source === "manual";
}
