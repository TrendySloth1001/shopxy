import type { VendorOverview } from "./schema";

/** Net purchased = total PURCHASE − total PURCHASE_RETURN. */
export function netPurchased(o: VendorOverview): number {
  const purchases = o.totals.filter((t) => t.type === "PURCHASE").reduce((s, t) => s + t.total, 0);
  const returns = o.totals.filter((t) => t.type === "PURCHASE_RETURN").reduce((s, t) => s + t.total, 0);
  return purchases - returns;
}

export function totalReturns(o: VendorOverview): number {
  return o.totals.filter((t) => t.type === "PURCHASE_RETURN").reduce((s, t) => s + t.total, 0);
}

/**
 * Balance semantics for a vendor (payable). Positive = the shop owes the
 * vendor; negative = an advance sits with the vendor.
 */
export type BalanceView = { label: string; tone: "owe" | "settled" | "advance" };

export function vendorBalanceView(balance: number): BalanceView {
  if (Math.abs(balance) < 0.005) return { label: "No outstanding", tone: "settled" };
  if (balance > 0) return { label: "You owe", tone: "owe" };
  return { label: "Advance with vendor", tone: "advance" };
}

/** Token text-colour for a balance tone. */
export const BALANCE_TONE_TEXT: Record<BalanceView["tone"], string> = {
  owe: "text-error",
  settled: "text-muted",
  advance: "text-success",
};
