import { INDIAN_STATES } from "@/shared/india";

/**
 * Place of supply, derived rather than asked for — the web mirror of the
 * Flutter merchant app's `_placeOfSupply` in `create_invoice_page.dart`.
 *
 * A GSTIN is `state(2) + PAN(10) + entity(1) + Z + checksum`, so the holder's
 * state is not a separate fact to collect — it's already in the number. Asking
 * for it again only invites a picked state that contradicts the GSTIN, which
 * is what puts tax under the wrong head (CGST/SGST where IGST is due).
 *
 * Mirrors the backend's own derivation (`invoices.service.ts` — the GST-10
 * fallback and the place-of-supply default) so the split shown here can't
 * disagree with the one saved.
 */

/** Where the derived answer came from, so the UI can say why. */
export type PosSource =
  | "partyGstin"
  | "partyAddress"
  | "vendorGstin"
  | "vendorAddress"
  | "shopDefault";

export type PlaceOfSupply = { code: string | null; source: PosSource };

/**
 * The GST state code encoded in a GSTIN's first two digits.
 *
 * Reads only the prefix rather than requiring a complete, well-formed GSTIN:
 * the merchant types left to right and the state is knowable from character
 * three onward. Returns null unless the prefix is two digits AND a real GST
 * state code, so "99…" or "ab…" derive nothing and the caller falls back.
 */
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

/**
 * Order: the counterparty's own state code → their GSTIN prefix → for a SALE,
 * the typed GSTIN's prefix → the shop's own state, because an unregistered
 * walk-in with no address is a local supply.
 */
export function derivePlaceOfSupply(args: {
  type: "SALE" | "PURCHASE";
  party: Counterparty;
  vendor: Counterparty;
  /** GSTIN typed into the walk-in form, when no party is attached. */
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
